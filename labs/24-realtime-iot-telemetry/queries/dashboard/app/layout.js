export const metadata = {
  title: "Lab 24 -- Live telemetry",
  description: "Realtime IoT telemetry streamed into Snowflake.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          background: "#0D1117",
          color: "#E6EDF3",
          fontFamily:
            "ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
        }}
      >
        {children}
      </body>
    </html>
  );
}
