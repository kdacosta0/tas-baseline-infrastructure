import http from "k6/http";
import { check, group, fail } from "k6";
import { b64encode, b64decode } from "k6/encoding";

export const options = {};

function reportError(component) {
    http.asyncRequest("POST", `http://localhost:8080/report-error?component=${component}`);
}

// Retrieves an OIDC token using the credentials from environment variables
function getOidcToken() {
    const issuerURL = __ENV.OIDC_ISSUER_URL;
    const user = __ENV.OIDC_USER;
    const password = __ENV.OIDC_PASSWORD;
    const clientID = __ENV.OIDC_CLIENT_ID;
    if (!issuerURL || !user || !password || !clientID) return null;

    const tokenURL = `${issuerURL}/protocol/openid-connect/token`;
    const payload = {
        username: user,
        password: password,
        scope: "openid",
        client_id: clientID,
        grant_type: "password",
    };
    const res = http.post(tokenURL, payload);
    if (res.status !== 200) {
        console.error(`OIDC token request failed: ${res.status} ${res.body}`);
        return null;
    }
    return res.json("access_token");
}

export function setup() {
    console.log("Fetching a single OIDC token for the entire test run...");
    const authToken = getOidcToken();
    if (!authToken) {
        console.error("Failed to retrieve OIDC token during setup. Cannot start the test.");
        return;
    }
    console.log("OIDC Token successfully retrieved. Starting VU iterations.");

    return { token: authToken };
}


export default function (data) {
    const authToken = data.token;

    const FULCIO_URL = __ENV.FULCIO_URL + "/api/v1/signingCert";
    const REKOR_URL = __ENV.REKOR_URL + "/api/v1/log/entries";

    // Fetches pre-generated cryptographic materials from the local helper service
    const helperRes = http.get(
        `http://localhost:8080/generate-payloads`,
        { tags: { name: "Helper_GetCrypto" } }
    );
    if (helperRes.status !== 200) {
        fail(
            `Failed to get crypto components from helper: ${helperRes.status} ${helperRes.body}`
        );
    }
    const crypto = helperRes.json();

    const liveHeaders = {
        Authorization: `Bearer ${authToken}`,
        "Content-Type": "application/json",
    };

    let fulcioCertificatePEM;
    let artifactSignature_b64 = crypto.artifactSignature;

    group("Workflow A: HashedRekord Entry", function () {
        group("1. Fulcio: Request Certificate", function () {
            const fulcioPayload = JSON.stringify({
                publicKey: { content: crypto.publicKeyBase64 },
                signedEmailAddress: crypto.signedEmailAddress,
            });
            const res = http.post(FULCIO_URL, fulcioPayload, {
                headers: liveHeaders,
                tags: { name: "Fulcio_RequestCert" },
            });
            if (check(res, { "Fulcio returned HTTP 201": (r) => r.status === 201 })) {
                // Extracts the PEM certificate from the Fulcio response body
                const certRegex =
                    /(-----BEGIN CERTIFICATE-----[^]+?-----END CERTIFICATE-----)/;
                const match = res.body.match(certRegex);
                if (match && match[0]) {
                    fulcioCertificatePEM = match[0];
                }
            } else {
                reportError('fulcio');
                fail(`Fulcio request failed: Status=${res.status}, Body=${res.body}`);
            }
        });

        group("2. Rekor: Create HashedRekord Entry", function () {
            const rekorPayload = JSON.stringify({
                apiVersion: "0.0.1",
                kind: "hashedrekord",
                spec: {
                    signature: {
                        content: crypto.artifactSignature,
                        publicKey: { content: b64encode(fulcioCertificatePEM) },
                    },
                    data: { hash: { algorithm: "sha256", value: crypto.artifactHash } },
                },
            });
            const res = http.post(REKOR_URL, rekorPayload, {
                headers: { "Content-Type": "application/json" },
                tags: { name: "Rekor_CreateHashedRekord" },
            });
            if (
                check(res, {
                    "Rekor (hashedrekord) returned HTTP 201": (r) => r.status === 201,
                })
            ) {
                if (__ENV.GENERATE_DATA_MODE) {
                    const location = res.headers["Location"];
                    if (location) {
                        const uuid = location.split("/").pop();
                        console.log(`REKOR_ENTRY_UUID:${uuid}`);
                    }
                }
            } else {
                reportError('rekor');
                fail(`Rekor (hashedrekord) request failed: Status=${res.status}, Body=${res.body}`);
            }
        });
    });

    if (!artifactSignature_b64) {
        console.error("Failed to get artifact signature, cannot proceed to TSA workflow");
        return;
    }

    group("Workflow B: RFC3161 Timestamp Entry", function () {
        let timestampResponse_b64;

        group("3. TSA: Request Timestamp", function () {
            const signatureBytes = b64decode(artifactSignature_b64, "std", "binary");

            const tsaRes = http.post(
                "http://localhost:8080/get-timestamp",
                signatureBytes,
                { 
                    headers: { "Content-Type": "application/octet-stream" },
                    tags: { name: "Helper_GetTimestamp" },
                }
            );

            if (
                check(tsaRes, {
                    "TSA Helper returned HTTP 200": (r) => r.status === 200,
                })
            ) {
                timestampResponse_b64 = tsaRes.body;
            } else {
                fail(`TSA helper request failed: Status=${tsaRes.status}, Body=${tsaRes.body}`);
            }
        });

        if (!timestampResponse_b64) {
            console.error("Failed to get timestamp from helper, cannot proceed");
            return;
        }

        group("4. Rekor: Create RFC3161 Entry", function () {
            const rekorPayload = JSON.stringify({
                apiVersion: "0.0.1",
                kind: "rfc3161",
                spec: {
                    tsr: {
                        content: b64encode(timestampResponse_b64),
                    },
                },
            });
            const res = http.post(REKOR_URL, rekorPayload, {
                headers: { "Content-Type": "application/json" },
                tags: { name: "Rekor_CreateRfc3161" },
            });
            if (
                !check(res, {
                    "Rekor (rfc3161) returned HTTP 201": (r) => r.status === 201,
                })
            ) {
                reportError('rekor');
                fail(`Rekor (rfc3161) request failed: Status=${res.status}, Body=${res.body}`);
            }
        });
    });
}