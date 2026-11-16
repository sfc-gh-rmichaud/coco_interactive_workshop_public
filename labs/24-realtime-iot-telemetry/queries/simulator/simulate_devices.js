// Device simulator for Lab 24. Streams sensor readings into Snowflake over the
// Snowpipe Streaming high-performance SDK.
//
// Run it with:
//   node simulate_devices.js
//
// Configuration comes from profile.json beside this file. See the lab README for
// the shape; setup.sql prints every value you need.
//
// What this is doing, and why each part is the way it is:
//
//   * The client binds to a PIPE, not to a table. That is the defining feature
//     of the high-performance architecture -- the pipe owns the mapping into the
//     table, so this code never names a column list.
//
//   * PAYLOAD is passed as a native JavaScript object. Passing JSON.stringify()
//     of the same thing "works" -- it lands, no error -- but arrives as VARCHAR
//     rather than OBJECT, and every later `PAYLOAD:key` reference silently
//     returns NULL. Verified: TYPEOF() is the only thing that tells you.
//
//   * appendRows() is fire-and-forget. It returns nothing and does not wait, so
//     the absence of an error here means nothing has been committed yet.
//     client.close() flushes and waits, which is what makes rows visible.
//
//   * Each batch carries an offset token. On a retry Snowflake reuses the latest
//     persisted token, so a re-sent batch is not double-counted. This is the
//     whole reason a streaming client can crash and restart safely.

const { createClient } = require("snowpipe-streaming");
const fs = require("fs");
const path = require("path");

const profile = JSON.parse(
  fs.readFileSync(path.join(__dirname, "profile.json"), "utf8")
);

// Five devices across two sites. DEVICE_ID 'press-02' is the one that develops
// a fault, so the vibration alerts view has something to find.
const DEVICES = [
  { id: "press-01", site: "Sheffield" },
  { id: "press-02", site: "Sheffield" },
  { id: "press-03", site: "Sheffield" },
  { id: "chiller-01", site: "Rotterdam" },
  { id: "chiller-02", site: "Rotterdam" },
];

const FAULTY_DEVICE = "press-02";
const FAULT_STARTS_AFTER_MS = 90_000;
const BATCH_INTERVAL_MS = 2_000;
const RUN_FOR_MS = Number(process.env.RUN_FOR_MS || 300_000); // 5 minutes

// TIMESTAMP_NTZ wants 'YYYY-MM-DD HH:MM:SS.sss'. An ISO string with a trailing Z
// is a TIMESTAMP_TZ and lands an hour or more out depending on your offset,
// which looks exactly like a broken clock on the device.
function ntz(date) {
  return date.toISOString().replace("T", " ").replace("Z", "");
}

function reading(device, startedAt) {
  const elapsed = Date.now() - startedAt;
  const faulty = device.id === FAULTY_DEVICE && elapsed > FAULT_STARTS_AFTER_MS;

  // Vibration climbs steadily once the fault starts, so the alert view fills up
  // gradually rather than all at once.
  const vibration = faulty
    ? 6.5 + ((elapsed - FAULT_STARTS_AFTER_MS) / 1000) * 0.12 + Math.random() * 0.6
    : 1.8 + Math.random() * 1.4;

  const base = device.site === "Rotterdam" ? 6 : 21;
  return {
    DEVICE_ID: device.id,
    SITE_NAME: device.site,
    READING_TS: ntz(new Date()),
    TEMP_C: Number((base + Math.random() * 3).toFixed(2)),
    HUMIDITY_PCT: Number((38 + Math.random() * 22).toFixed(1)),
    VIBRATION_MM: Number(vibration.toFixed(2)),
    // A native object. NOT JSON.stringify(...) -- see the note at the top.
    PAYLOAD: {
      device: device.id,
      site: device.site,
      firmware: "2.4.1",
      faulty_mode: faulty,
    },
  };
}

async function main() {
  const properties = {
    authorization_type: profile.authorization_type || "JWT",
    url: `https://${profile.account}.snowflakecomputing.com`,
    account: profile.account,
    user: profile.user,
    role: profile.role,
  };
  if (properties.authorization_type === "JWT") {
    properties.private_key = fs.readFileSync(profile.private_key_file, "utf8");
  } else if (properties.authorization_type === "PAT") {
    properties.personal_access_token = profile.personal_access_token;
  }

  const client = await createClient({
    clientName: "coco-lab24-simulator",
    dbName: profile.database,
    schemaName: profile.schema,
    pipeName: profile.pipe,
    properties,
  });

  // openChannel takes `name` (not `channelName`) and returns { channel, status }.
  // Getting either wrong fails with a bare "Failed to convert JavaScript value
  // `Undefined` into rust type `String`", which does not point at the cause.
  const { channel, status } = await client.openChannel({ name: "simulator-1" });
  console.log(
    `channel open (${status ? "reopened, resuming from persisted offset" : "new"})`
  );

  const startedAt = Date.now();
  let batches = 0;
  let rowsSent = 0;

  const timer = setInterval(() => {
    const rows = DEVICES.map((d) => reading(d, startedAt));
    batches += 1;
    // One offset token per batch. On a restart Snowflake resumes from the last
    // persisted token, so this batch is not applied twice.
    channel.appendRows(rows, `batch-${batches}`);
    rowsSent += rows.length;
    const secs = Math.round((Date.now() - startedAt) / 1000);
    process.stdout.write(
      `\rt+${secs}s  batches=${batches}  rows sent=${rowsSent}   `
    );
  }, BATCH_INTERVAL_MS);

  setTimeout(async () => {
    clearInterval(timer);
    console.log("\nflushing...");
    // Flushes and waits by default. This is the call that commits; until it
    // returns, a SELECT can legitimately show fewer rows than were sent.
    await client.close();
    console.log(`done. sent ${rowsSent} rows in ${batches} batches.`);
    console.log(
      "Rows become visible a few seconds after this point, not immediately."
    );
  }, RUN_FOR_MS);
}

main().catch((e) => {
  console.error("\nsimulator failed:", e && e.message ? e.message : e);
  process.exit(1);
});
