const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");

const paypalClientId = defineSecret("PAYPAL_CLIENT_ID");
const paypalClientSecret = defineSecret("PAYPAL_CLIENT_SECRET");
const paypalMode = defineString("PAYPAL_MODE", { default: "sandbox" });

function getBaseUrl() {
  return paypalMode.value() === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";
}

function setCors(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

async function getAccessToken() {
  const clientId = paypalClientId.value();
  const clientSecret = paypalClientSecret.value();
  if (!clientId || !clientSecret) {
    throw new Error("PayPal credentials not configured");
  }
  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const response = await fetch(`${getBaseUrl()}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error_description || "Failed to get access token");
  }
  return data.access_token;
}

exports.createPayPalOrder = onRequest(
  { secrets: [paypalClientId, paypalClientSecret] },
  async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }
  try {
    const { amount, currency, return_url, cancel_url } = req.body || {};
    if (!amount || !currency || !return_url || !cancel_url) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }
    const accessToken = await getAccessToken();
    const response = await fetch(`${getBaseUrl()}/v2/checkout/orders`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        intent: "CAPTURE",
        purchase_units: [
          {
            amount: {
              currency_code: currency,
              value: amount,
            },
          },
        ],
        application_context: {
          return_url,
          cancel_url,
        },
      }),
    });
    const data = await response.json();
    if (!response.ok) {
      res.status(400).json({ error: data });
      return;
    }
    const approvalLink =
      data.links && data.links.find((link) => link.rel === "approve");
    res.json({
      orderId: data.id,
      approvalUrl: approvalLink ? approvalLink.href : null,
    });
  } catch (error) {
    res.status(500).json({ error: error.message || "PayPal order failed" });
  }
  }
);

exports.capturePayPalOrder = onRequest(
  { secrets: [paypalClientId, paypalClientSecret] },
  async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }
  try {
    const { orderId } = req.body || {};
    if (!orderId) {
      res.status(400).json({ error: "Missing orderId" });
      return;
    }
    const accessToken = await getAccessToken();
    const response = await fetch(
      `${getBaseUrl()}/v2/checkout/orders/${orderId}/capture`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      }
    );
    const data = await response.json();
    if (!response.ok) {
      res.status(400).json({ error: data });
      return;
    }
    res.json({ status: "COMPLETED", data });
  } catch (error) {
    res.status(500).json({ error: error.message || "PayPal capture failed" });
  }
  }
);

exports.paypalSuccess = onRequest((req, res) => {
  res
    .status(200)
    .send(
      "<html><body style='font-family: Arial, sans-serif; text-align:center; padding:40px;'>" +
        "<h2>Payment approved</h2>" +
        "<p>You can return to the app to complete checkout.</p>" +
        "</body></html>"
    );
});

exports.paypalCancel = onRequest((req, res) => {
  res
    .status(200)
    .send(
      "<html><body style='font-family: Arial, sans-serif; text-align:center; padding:40px;'>" +
        "<h2>Payment cancelled</h2>" +
        "<p>You can return to the app to try again.</p>" +
        "</body></html>"
    );
});
