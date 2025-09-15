import http from 'k6/http';
import { check, group } from 'k6';
import { b64decode } from 'k6/encoding';

// Simulates a verification workflow using a list of pre-existing Rekor UUIDs.
export const options = {};

// Load Rekor UUIDs to be shared across all VUs.
let uuids;
if (__ENV.REKOR_UUIDS) {
    uuids = __ENV.REKOR_UUIDS.split(',');
} else {
    throw new Error("No UUIDs provided. Please set the REKOR_UUIDS environment variable.");
}

export default function () {
    const randomIndex = Math.floor(Math.random() * uuids.length);
    const uuidToVerify = uuids[randomIndex];

    const REKOR_URL = __ENV.REKOR_URL;
    const TSA_URL = __ENV.TSA_URL;

    group('Workflow: Verify Signature', function() {
        group('1. Rekor: Get Log Entry by UUID', function () {
            const getEntryUrl = `${REKOR_URL}/api/v1/log/entries/${uuidToVerify}`;
            const res = http.get(getEntryUrl, {tags: { name: 'Rekor_GetEntryByUUID' },});

            const statusOK = check(res, { 'Rekor GET returned HTTP 200': (r) => r.status === 200 });

            if (statusOK) {
                const rekorEntry = res.json();
                check(rekorEntry, {
                    'Rekor response contains the correct entry UUID': (entry) => entry.hasOwnProperty(uuidToVerify),
                });

                try {
                    const entryData = rekorEntry[uuidToVerify];
                    const decodedBody = JSON.parse(b64decode(entryData.body, 'std', 's'));
                    check(decodedBody, {
                        'Rekor entry body contains a signature block': (b) => b.spec && b.spec.signature,
                    });
                } catch (e) {
                    check(null, { 'Rekor response body was not valid JSON': () => false });
                }
            }
        });

        // Get the TSA's certificate chain to verify the timestamp.
        group('2. TSA: Get Certificate Chain', function() {
            const certChainUrl = `${TSA_URL}/certchain`;
            const res = http.get(certChainUrl, {
                tags: { name: 'TSA_GetCertChain' },
            });
            check(res, { 'TSA GET certchain returned HTTP 200': (r) => r.status === 200 });
        });
    });
}
