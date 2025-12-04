// lambda/getTestRuns.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  try {
    const params = event.queryStringParameters || {};
    const limit = parseInt(params.limit) || 50;
    const status = params.status; // Optional filter by status
    
    const scanParams = {
      TableName: process.env.TEST_RUNS_TABLE,
      Limit: limit
    };
    
    // Add filter expression if status is provided
    if (status) {
      scanParams.FilterExpression = '#status = :status';
      scanParams.ExpressionAttributeNames = { '#status': 'status' };
      scanParams.ExpressionAttributeValues = { ':status': status };
    }
    
    const result = await docClient.send(new ScanCommand(scanParams));
    
    // Sort by timestamp descending (most recent first)
    const sortedRuns = result.Items.sort((a, b) => 
      new Date(b.timestamp) - new Date(a.timestamp)
    );
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        testRuns: sortedRuns,
        count: sortedRuns.length
      })
    };
  } catch (error) {
    console.error('Error fetching test runs:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Failed to fetch test runs' })
    };
  }
};
