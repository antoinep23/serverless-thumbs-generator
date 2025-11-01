const API_BASE =
  'https://szkyvmnr24.execute-api.eu-west-3.amazonaws.com/Stage1';

document.getElementById('uploadBtn').addEventListener('click', async () => {
  const fileInput = document.getElementById('fileInput');
  const statusEl = document.getElementById('status');

  if (!fileInput.files.length) {
    statusEl.textContent = 'Please select a file first';
    return;
  }

  const file = fileInput.files[0];
  statusEl.textContent = 'Requesting upload URL...';

  try {
    // 1) Get pre-signed URL via API Gateway
    const req = await fetch(`${API_BASE}/getSignedUrl`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fileName: file.name, contentType: file.type }),
    });

    const res = await req.json();
    const bodyData = JSON.parse(res.body);
    const uploadUrl = bodyData.uploadUrl;

    // 2) Upload file to S3 using the pre-signed URL
    statusEl.textContent = 'Uploading file...';
    await fetch(uploadUrl, {
      method: 'PUT',
      headers: {
        'Access-Control-Allow-Origin':
          'http://thumbs-serverless-frontend.s3-website.eu-west-3.amazonaws.com',
        'Content-Type': file.type,
      },
      body: file,
    });

    statusEl.textContent = '✅ Upload complete!';
  } catch (err) {
    console.error(err);
    statusEl.textContent = '❌ Error uploading file.';
  }
});
