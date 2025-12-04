# Griffler API - Serverless Backend

Complete serverless API for the Griffler testing dashboard, deployed on AWS with Lambda, DynamoDB, S3, and API Gateway.

## Architecture

```
┌─────────────────┐
│  React Dashboard│ (S3 + CloudFront)
│    (Frontend)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  API Gateway    │ (HTTP API)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Lambda Functions│
│  - Create Run   │
│  - Get Runs     │
│  - Update Run   │
│  - Artifacts    │
└────┬────────┬───┘
     │        │
     ▼        ▼
┌─────────┐  ┌──────┐
│DynamoDB │  │  S3  │
│(Metadata)  │(Files)│
└─────────┘  └──────┘
```

## Project Structure

```
griffler/
├── lambda/
│   ├── createTestRun.js
│   ├── getTestRuns.js
│   ├── getTestRunById.js
│   ├── updateTestRun.js
│   ├── uploadArtifact.js
│   └── getArtifact.js
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── package.json
├── build.js
└── README.md
```

## Prerequisites

- **Node.js** 18+ and npm
- **Terraform** 1.0+
- **AWS CLI** configured with credentials
- AWS account with appropriate permissions

## Setup & Deployment

### 1. Install Dependencies

```bash
npm install
```

### 2. Build Lambda Packages

```bash
npm run build
```

This creates ZIP files for each Lambda function in the `lambda/` directory.

### 3. Configure Terraform Variables

Edit `terraform/variables.tf` or create `terraform/terraform.tfvars`:

```hcl
aws_region   = "us-east-1"
project_name = "griffler"
environment  = "dev"
```

### 4. Initialize Terraform

```bash
cd terraform
terraform init
```

### 5. Deploy Infrastructure

```bash
terraform plan
terraform apply
```

This creates:
- DynamoDB table for test runs
- S3 buckets (artifacts + dashboard)
- Lambda functions (6 total)
- API Gateway with routes
- IAM roles and policies

### 6. Get API Endpoint

```bash
terraform output api_endpoint
```

Copy this URL - you'll need it for the dashboard and test runners.

## API Endpoints

Base URL: `https://{api-id}.execute-api.{region}.amazonaws.com`

### Test Runs

**Create Test Run**
```bash
POST /test-runs
Content-Type: application/json

{
  "prNumber": 142,
  "prTitle": "Add new feature",
  "prAuthor": "developer",
  "commitSha": "abc123",
  "commitMessage": "feat: implement feature"
}
```

**Get All Test Runs**
```bash
GET /test-runs?limit=50&status=passed
```

**Get Test Run by ID**
```bash
GET /test-runs/{id}
```

**Update Test Run**
```bash
PATCH /test-runs/{id}
Content-Type: application/json

{
  "status": "passed",
  "playwrightUi": {
    "total": 24,
    "passed": 24,
    "failed": 0
  },
  "duration": "4m 32s"
}
```

### Artifacts

**Upload Artifact (Get Pre-signed URL)**
```bash
POST /test-runs/{id}/artifacts
Content-Type: application/json

{
  "filename": "screenshot.png",
  "contentType": "image/png"
}

Response:
{
  "uploadUrl": "https://s3.amazonaws.com/...",
  "s3Key": "test-runs/{id}/artifacts/screenshot.png",
  "artifactUrl": "https://..."
}
```

**Get Artifact Download URL**
```bash
GET /test-runs/{id}/artifacts/{filename}

Response:
{
  "downloadUrl": "https://s3.amazonaws.com/...",
  "filename": "screenshot.png",
  "expiresIn": 3600
}
```

## Usage Examples

### From Test Runner (Playwright/Locust)

```javascript
// 1. Create test run
const response = await fetch(`${API_URL}/test-runs`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    prNumber: process.env.PR_NUMBER,
    prTitle: process.env.PR_TITLE,
    prAuthor: process.env.PR_AUTHOR,
    commitSha: process.env.COMMIT_SHA,
    commitMessage: process.env.COMMIT_MESSAGE
  })
});
const testRun = await response.json();
const testRunId = testRun.id;

// 2. Upload screenshot
const uploadResponse = await fetch(`${API_URL}/test-runs/${testRunId}/artifacts`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    filename: 'screenshot.png',
    contentType: 'image/png'
  })
});
const { uploadUrl } = await uploadResponse.json();

// Upload file to S3
await fetch(uploadUrl, {
  method: 'PUT',
  body: screenshotBuffer,
  headers: { 'Content-Type': 'image/png' }
});

// 3. Update test results
await fetch(`${API_URL}/test-runs/${testRunId}`, {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    status: 'passed',
    playwrightUi: { total: 24, passed: 24, failed: 0 },
    playwrightApi: { total: 18, passed: 18, failed: 0 },
    locust: { rps: 245, avgResponseTime: 124, errorRate: 0.1 },
    duration: '4m 32s'
  })
});
```

## Environment Variables

Lambda functions use these environment variables (set by Terraform):

- `TEST_RUNS_TABLE` - DynamoDB table name
- `ARTIFACTS_BUCKET` - S3 bucket for artifacts

## Data Model

### DynamoDB Test Run Item

```json
{
  "id": "uuid",
  "timestamp": "2024-12-04T10:30:00Z",
  "prNumber": 142,
  "prTitle": "Add user authentication",
  "prAuthor": "developer",
  "commitSha": "abc123",
  "commitMessage": "feat: add OAuth",
  "status": "passed|failed|running",
  "testappUrl": "https://...",
  "apiUrl": "https://...",
  "startTime": "2024-12-04T10:30:00Z",
  "endTime": "2024-12-04T10:34:32Z",
  "duration": "4m 32s",
  "playwrightUi": {
    "total": 24,
    "passed": 24,
    "failed": 0,
    "results": []
  },
  "playwrightApi": {
    "total": 18,
    "passed": 18,
    "failed": 0,
    "results": []
  },
  "locust": {
    "rps": 245,
    "avgResponseTime": 124,
    "errorRate": 0.1
  },
  "screenshots": ["screenshot1.png", "screenshot2.png"],
  "artifacts": ["test-report.html", "coverage.json"]
}
```

## Monitoring & Logs

View Lambda logs in CloudWatch:

```bash
aws logs tail /aws/lambda/griffler-create-test-run --follow
```

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## Cost Estimation

**Monthly costs (dev environment, low traffic):**
- DynamoDB: $0-5 (on-demand pricing)
- Lambda: $0-5 (1M free requests/month)
- API Gateway: $0-5 (1M free requests/month)
- S3: $0-10 (storage + requests)

**Total: ~$0-25/month for low usage**

## Next Steps

1. ✅ Deploy infrastructure with Terraform
2. ⏭️ Build testapp-staging (webapp to test)
3. ⏭️ Create test-cluster (Playwright + Locust)
4. ⏭️ Set up GitHub Actions workflow
5. ⏭️ Connect dashboard to real API

## Troubleshooting

**Lambda function fails to deploy:**
- Ensure ZIP files exist in `lambda/` directory
- Run `npm run build` first

**API Gateway 403 errors:**
- Check Lambda permissions
- Verify IAM role policies

**DynamoDB errors:**
- Verify table name in environment variables
- Check IAM role has DynamoDB permissions

## Support

For issues or questions, check the Lambda logs in CloudWatch or run:

```bash
terraform output
```

To see all deployed resources and their URLs.