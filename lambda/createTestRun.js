// lambda/createTestRun.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { v4: uuidv4 } = require('uuid');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  try {
    const body = JSON.parse(event.body);
    
    // Validate required fields
    const requiredFields = ['prNumber', 'prTitle', 'prAuthor', 'commitSha', 'commitMessage'];
    for (const field of requiredFields) {
      if (!body[field]) {
        return {
          statusCode: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify({ error: `Missing required field: ${field}` })
        };
      }
    }
    
    const testRunId = uuidv4();
    const timestamp = new Date().toISOString();
    
    const testRun = {
      id: testRunId,
      timestamp,
      prNumber: body.prNumber,
      prTitle: body.prTitle,
      prAuthor: body.prAuthor,
      commitSha: body.commitSha,
      commitMessage: body.commitMessage,
      status: 'running',
      testappUrl: body.testappUrl || `https://testapp-pr${body.prNumber}.staging.example.com`,
      apiUrl: body.apiUrl || `https://api-pr${body.prNumber}.staging.example.com`,
      startTime: timestamp,
      playwrightUi: {
        total: 0,
        passed: 0,
        failed: 0,
        results: []
      },
      playwrightApi: {
        total: 0,
        passed: 0,
        failed: 0,
        results: []
      },
      locust: null,
      screenshots: [],
      artifacts: [],
      duration: null
    };
    
    await docClient.send(new PutCommand({
      TableName: process.env.TEST_RUNS_TABLE,
      Item: testRun
    }));
    
    return {
      statusCode: 201,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify(testRun)
    };
  } catch (error) {
    console.error('Error creating test run:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Failed to create test run' })
    };
  }
};
