// lambda/updateTestRun.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, UpdateCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  try {
    const testRunId = event.pathParameters?.id;
    const body = JSON.parse(event.body);
    
    if (!testRunId) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Test run ID is required' })
      };
    }
    
    // Check if test run exists
    const existingRun = await docClient.send(new GetCommand({
      TableName: process.env.TEST_RUNS_TABLE,
      Key: { id: testRunId }
    }));
    
    if (!existingRun.Item) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Test run not found' })
      };
    }
    
    // Build update expression dynamically
    const updateExpressions = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};
    
    const allowedFields = [
      'status', 
      'playwrightUi', 
      'playwrightApi', 
      'locust', 
      'screenshots', 
      'artifacts', 
      'duration',
      'endTime'
    ];
    
    let index = 0;
    for (const field of allowedFields) {
      if (body[field] !== undefined) {
        const attrName = `#attr${index}`;
        const attrValue = `:val${index}`;
        updateExpressions.push(`${attrName} = ${attrValue}`);
        expressionAttributeNames[attrName] = field;
        expressionAttributeValues[attrValue] = body[field];
        index++;
      }
    }
    
    // If status is being set to passed or failed, add endTime
    if (body.status && ['passed', 'failed'].includes(body.status) && !body.endTime) {
      const attrName = `#attr${index}`;
      const attrValue = `:val${index}`;
      updateExpressions.push(`${attrName} = ${attrValue}`);
      expressionAttributeNames[attrName] = 'endTime';
      expressionAttributeValues[attrValue] = new Date().toISOString();
    }
    
    if (updateExpressions.length === 0) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'No valid fields to update' })
      };
    }
    
    const result = await docClient.send(new UpdateCommand({
      TableName: process.env.TEST_RUNS_TABLE,
      Key: { id: testRunId },
      UpdateExpression: `SET ${updateExpressions.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    }));
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify(result.Attributes)
    };
  } catch (error) {
    console.error('Error updating test run:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Failed to update test run' })
    };
  }
};
