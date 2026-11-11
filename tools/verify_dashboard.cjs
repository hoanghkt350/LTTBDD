// Read-only production check. OAuth credentials stay inside adminClient.
const assert = require('node:assert/strict');
const { adminClient } = require('./firebase_admin.cjs');

async function main() {
  const project = process.argv[2];
  const request = await adminClient(project);
  const database = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)`;
  let index;
  for (let attempt = 0; attempt < 18; attempt++) {
    const result = await request(`${database}/collectionGroups/orders/indexes`);
    index = result.indexes?.find(item => item.queryScope === 'COLLECTION' &&
      ['status', 'statusUpdatedAt', 'totalAmount'].every((field, i) =>
        item.fields?.[i]?.fieldPath === field && item.fields[i].order === 'ASCENDING'));
    if (index?.state !== 'CREATING') break;
    await new Promise(resolve => setTimeout(resolve, 10000));
  }
  assert.equal(index?.state, 'READY', 'The dashboard index must be READY.');
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
  const start = new Date(`${day}T00:00:00+07:00`);
  const end = new Date(start.getTime() + 86400000);
  const aggregation = await request(`${database}/documents:runAggregationQuery`, {
    method: 'POST',
    body: {structuredAggregationQuery: {
      structuredQuery: {
        from: [{collectionId: 'orders'}],
        where: {compositeFilter: {op: 'AND', filters: [
          {fieldFilter: {field: {fieldPath: 'status'}, op: 'EQUAL', value: {stringValue: 'Hoàn thành'}}},
          {fieldFilter: {field: {fieldPath: 'statusUpdatedAt'}, op: 'GREATER_THAN_OR_EQUAL', value: {timestampValue: start.toISOString()}}},
          {fieldFilter: {field: {fieldPath: 'statusUpdatedAt'}, op: 'LESS_THAN', value: {timestampValue: end.toISOString()}}},
        ]}},
      },
      aggregations: [
        {alias: 'completedOrders', count: {}},
        {alias: 'revenue', sum: {field: {fieldPath: 'totalAmount'}}},
      ],
    }},
  });
  const fields = aggregation.find(row => row.result)?.result.aggregateFields;
  assert.ok(fields?.completedOrders && fields?.revenue, 'The aggregate response must contain count and sum.');
  console.log(JSON.stringify({project,indexState:index.state,aggregation:'passed',readOnly:true},null,2));
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
