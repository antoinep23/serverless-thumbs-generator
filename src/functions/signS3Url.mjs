import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({ region: process.env.AWS_REGION });
const RAW_BUCKET = process.env.RAW_BUCKET;
const FRONTEND_URL = process.env.FRONTEND_URL;

export const handler = async (event) => {
  try {
    const body =
      typeof event.body === 'string'
        ? JSON.parse(event.body)
        : event.body || {};

    const fileName = body.fileName || 'upload.jpg';
    const contentType = body.contentType || 'image/jpeg';

    if (!fileName || !contentType) {
      return {
        statusCode: 400,
        headers: {
          'Access-Control-Allow-Origin': `https://${process.env.FRONTEND_URL}`,
        },
        body: JSON.stringify({ error: 'Missing fileName or contentType' }),
      };
    }

    const key = `raw/${Date.now()}-${Math.random()
      .toString(36)
      .substring(2, 15)}-${fileName}`;

    const command = new PutObjectCommand({
      Bucket: process.env.RAW_BUCKET,
      Key: key,
      ContentType: contentType,
    });

    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 60 });

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': `https://${process.env.FRONTEND_URL}`,
        'Access-Control-Allow-Headers': 'Content-Type',
      },
      body: JSON.stringify({ uploadUrl, key }),
    };
  } catch (err) {
    console.error(err);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': `https://${process.env.FRONTEND_URL}`,
      },
      body: JSON.stringify({ error: 'Could not generate URL' }),
    };
  }
};
