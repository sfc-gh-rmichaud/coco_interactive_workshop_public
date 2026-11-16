"use client";

// The live dashboard. Polls the API route every two seconds and redraws.
//
// Polling rather than a websocket, deliberately: the ingest lag you measured in
// step 3 is several seconds, so a push channel would spend most of its time
// pushing nothing. Two seconds is comfortably faster than data arrives, which is
// the right relationship between a poll interval and a pipeline's latency.

import { useEffect, useState } from "react";
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

const POLL_MS = 2000;
const ACCENT = "#29B5E8";
const WARN = "#F0883E";

export default function Page() {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function poll() {
      try {
        const res = await fetch("/api/readings", { cache: "no-store" });
        const body = await res.json();
        if (cancelled) return;
        if (body.ok) {
          setData(body);
          setError(null);
        } else {
          setError(body.error);
        }
      } catch (e) {
        if (!cancelled) setError(e.message);
      }
    }

    poll();
    const timer = setInterval(poll, POLL_MS);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  const totals = data?.totals ?? {};
  const series = data?.series ?? [];
  const alerts = data?.alerts ?? [];

  // Line per site, discovered from the data rather than hardcoded, so adding a
  // site to the simulator needs no change here.
  const tempKeys = [
    ...new Set(series.flatMap((row) => Object.keys(row).filter((k) => k.endsWith(" temp")))),
  ];

  return (
    <main style={{ padding: "1.5rem 2rem", maxWidth: 1100, margin: "0 auto" }}>
      <p style={{ color: ACCENT, letterSpacing: ".08em", fontSize: ".78rem", margin: 0 }}>
        COCO WORKSHOP &middot; LAB 24
      </p>
      <h1 style={{ margin: ".2rem 0 1.2rem", fontSize: "1.6rem" }}>Live sensor telemetry</h1>

      {error && (
        <div
          style={{
            background: "#3D1D1D",
            border: "1px solid #A74B4B",
            borderRadius: 10,
            padding: ".8rem 1rem",
            marginBottom: "1rem",
            fontSize: ".9rem",
          }}
        >
          <strong>Query failed.</strong> {error}
        </div>
      )}

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "1rem" }}>
        <Stat label="Readings" value={totals.TOTAL_READINGS ?? "--"} />
        <Stat label="Devices" value={totals.DEVICES ?? "--"} />
        <Stat label="Newest reading" value={totals.NEWEST ?? "--"} />
        <Stat
          label="Behind live"
          value={totals.LAG_SECONDS != null ? `${totals.LAG_SECONDS}s` : "--"}
          warn={totals.LAG_SECONDS > 30}
        />
      </div>

      <Panel title="Average temperature by site, 10-second buckets">
        {series.length === 0 ? (
          <Empty />
        ) : (
          <ResponsiveContainer width="100%" height={260}>
            <LineChart data={series}>
              <CartesianGrid stroke="#2A3441" />
              <XAxis dataKey="T" stroke="#9DA7B3" fontSize={11} />
              <YAxis stroke="#9DA7B3" fontSize={11} unit="&deg;C" />
              <Tooltip
                contentStyle={{ background: "#161B22", border: "1px solid #2A3441" }}
              />
              <Legend />
              {tempKeys.map((key, i) => (
                <Line
                  key={key}
                  type="monotone"
                  dataKey={key}
                  stroke={i === 0 ? ACCENT : WARN}
                  dot={false}
                  strokeWidth={2}
                  isAnimationActive={false}
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
        )}
      </Panel>

      <Panel title="Vibration alerts above 8mm">
        {alerts.length === 0 ? (
          <p style={{ color: "#9DA7B3", fontSize: ".9rem", margin: 0 }}>
            Nothing yet. The simulator injects a fault into one device after about
            90 seconds, so this fills in while you watch.
          </p>
        ) : (
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: ".9rem" }}>
            <thead>
              <tr style={{ textAlign: "left", color: "#9DA7B3" }}>
                <th style={{ padding: ".3rem 0" }}>Device</th>
                <th>Site</th>
                <th>Time</th>
                <th style={{ textAlign: "right" }}>Vibration</th>
              </tr>
            </thead>
            <tbody>
              {alerts.map((a, i) => (
                <tr key={i} style={{ borderTop: "1px solid #2A3441" }}>
                  <td style={{ padding: ".35rem 0" }}>{a.DEVICE_ID}</td>
                  <td>{a.SITE_NAME}</td>
                  <td>{a.T}</td>
                  <td style={{ textAlign: "right", color: WARN }}>
                    {a.VIBRATION_MM} mm
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>

      <p style={{ color: "#5A6B78", fontSize: ".78rem" }}>
        Polling every {POLL_MS / 1000}s
        {data?.fetchedAt ? ` \u00b7 last fetch ${data.fetchedAt.slice(11, 19)} UTC` : ""}
      </p>
    </main>
  );
}

function Stat({ label, value, warn }) {
  return (
    <div
      style={{
        background: "#161B22",
        border: `1px solid ${warn ? WARN : "#2A3441"}`,
        borderRadius: 12,
        padding: ".8rem 1rem",
      }}
    >
      <div style={{ color: "#9DA7B3", fontSize: ".74rem", textTransform: "uppercase" }}>
        {label}
      </div>
      <div style={{ fontSize: "1.5rem", fontWeight: 600, color: warn ? WARN : "#E6EDF3" }}>
        {value}
      </div>
    </div>
  );
}

function Panel({ title, children }) {
  return (
    <section
      style={{
        background: "#161B22",
        border: "1px solid #2A3441",
        borderRadius: 12,
        padding: "1rem 1.1rem",
        margin: "1.2rem 0",
      }}
    >
      <h2 style={{ fontSize: ".95rem", margin: "0 0 .8rem", color: "#E6EDF3" }}>{title}</h2>
      {children}
    </section>
  );
}

function Empty() {
  return (
    <p style={{ color: "#9DA7B3", fontSize: ".9rem", margin: 0 }}>
      No readings in the last 15 minutes. Start the simulator, then give it a few
      seconds -- streamed rows are not visible the instant they are sent.
    </p>
  );
}
