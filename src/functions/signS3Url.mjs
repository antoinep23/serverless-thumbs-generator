import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({ region: process.env.AWS_REGION });
const RAW_BUCKET = process.env.RAW_BUCKET;

export const handler = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const fileName = body.fileName;
    const contentType = body.contentType;

    if (!fileName || !contentType) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing fileName or contentType' }),
      };
    }

    // Generate a key in the /raw folder
    const key = `raw/${Date.now()}-${Math.random()
      .toString(36)
      .substring(2, 15)}-${fileName}`;

    const command = new PutObjectCommand({
      Bucket: RAW_BUCKET,
      Key: key,
      ContentType: contentType,
    });

    // URL available for 1 min
    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 60 });

    return {
      statusCode: 200,
      body: JSON.stringify({ uploadUrl, key }),
    };
  } catch (err) {
    console.error(err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Could not generate URL' }),
    };
  }
};
