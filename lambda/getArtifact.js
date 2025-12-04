// lambda/getArtifact.js
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const s3Client = new S3Client({});

exports.handler = async (event) => {
  try {
    const testRunId = event.pathParameters?.id;
    const filename = event.pathParameters?.filename;
    
    if (!testRunId || !filename) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Test run ID and filename are required' })
      };
    }
    
    // Generate S3 key
    const s3Key = `test-runs/${testRunId}/artifacts/${filename}`;
    
    // Generate pre-signed URL for download
    const command = new GetObjectCommand({
      Bucket: process.env.ARTIFACTS_BUCKET,
      Key: s3Key
    });
    
    const downloadUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        downloadUrl,
        filename,
        expiresIn: 3600
      })
    };
  } catch (error) {
    console.error('Error generating download URL:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Failed to generate download URL' })
    };
  }
};
