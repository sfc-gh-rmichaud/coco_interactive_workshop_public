// Server-side API route: reads the live telemetry views and hands the browser
// plain JSON. The Snowflake connection lives here and only here -- the browser
// never sees a credential, which is the point of putting a route in front of it.
//
// One connection is reused across requests. A dashboard polling every two
// seconds would otherwise open a connection per poll, and Snowflake would spend
// more time authenticating than answering.

import fs from "node:fs";
import snowflake from "snowflake-sdk";

// The SDK logs every statement at INFO by default, which buries the app's own
// output within seconds.
snowflake.configure({ logLevel: "ERROR" });

let connectionPromise = null;

function connect() {
  if (connectionPromise) return connectionPromise;

  connectionPromise = new Promise((resolve, reject) => {
    const connection = snowflake.createConnection({
      account: process.env.SNOWFLAKE_ACCOUNT,
      username: process.env.SNOWFLAKE_USER,
      role: process.env.SNOWFLAKE_ROLE,
      warehouse: process.env.SNOWFLAKE_WAREHOUSE,
      database: process.env.SNOWFLAKE_DATABASE,
      schema: process.env.SNOWFLAKE_SCHEMA,
      authenticator: "SNOWFLAKE_JWT",
      privateKey: fs.readFileSync(process.env.SNOWFLAKE_PRIVATE_KEY_PATH, "utf8"),
    });
    connection.connect((err, conn) => (err ? reject(err) : resolve(conn)));
  });

  // A failed connection must not be cached, or every later request reuses the
  // rejection and the dashboard never recovers without a restart.
  connectionPromise.catch(() => {
    connectionPromise = null;
  });

  return connectionPromise;
}

function query(connection, sqlText) {
  return new Promise((resolve, reject) => {
    connection.execute({
      sqlText,
      complete: (err, _stmt, rows) => (err ? reject(err) : resolve(rows)),
    });
  });
}

export async function GET() {
  try {
    const connection = await connect();

    const [series, alerts, totals] = await Promise.all([
      query(
        connection,
        `SELECT SITE_NAME, TO_VARCHAR(BUCKET_TS, 'HH24:MI:SS') AS T,
                AVG_TEMP_C, MAX_VIBRATION_MM, READINGS
         FROM V_SITE_TELEMETRY
         ORDER BY BUCKET_TS`
      ),
      query(
        connection,
        `SELECT DEVICE_ID, SITE_NAME,
                TO_VARCHAR(READING_TS, 'HH24:MI:SS') AS T, VIBRATION_MM
         FROM V_VIBRATION_ALERTS
         ORDER BY READING_TS DESC
         LIMIT 10`
      ),
      query(
        connection,
        `SELECT COUNT(*) AS TOTAL_READINGS,
                COUNT(DISTINCT DEVICE_ID) AS DEVICES,
                TO_VARCHAR(MAX(READING_TS), 'HH24:MI:SS') AS NEWEST,
                -- SYSDATE(), not CURRENT_TIMESTAMP(): READING_TS is UTC in a
                -- TIMESTAMP_NTZ, and CURRENT_TIMESTAMP() is session-local, so
                -- the difference would be off by the UTC offset.
                DATEDIFF('second', MAX(READING_TS), SYSDATE()) AS LAG_SECONDS
         FROM SENSOR_READINGS`
      ),
    ]);

    return Response.json({
      ok: true,
      // Pivot to one object per bucket so the chart can plot a line per site
      // without knowing the site names up front.
      series: pivot(series),
      alerts,
      totals: totals[0] ?? {},
      fetchedAt: new Date().toISOString(),
    });
  } catch (error) {
    // Returned rather than thrown: the dashboard shows the message, which is far
    // more useful than a blank panel when a warehouse is suspended or a
    // credential is wrong.
    return Response.json(
      { ok: false, error: error.message ?? String(error) },
      { status: 500 }
    );
  }
}

function pivot(rows) {
  const byBucket = new Map();
  for (const row of rows) {
    if (!byBucket.has(row.T)) byBucket.set(row.T, { T: row.T });
    const entry = byBucket.get(row.T);
    entry[`${row.SITE_NAME} temp`] = row.AVG_TEMP_C;
    entry[`${row.SITE_NAME} vib`] = row.MAX_VIBRATION_MM;
  }
  return [...byBucket.values()];
}
