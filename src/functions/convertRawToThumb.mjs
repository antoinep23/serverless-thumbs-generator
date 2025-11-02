import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import sharp from 'sharp';

const THUMB_WIDTH = 200;
const THUMB_HEIGHT = 200;
const THUMB_QUALITY = 85;

const s3 = new S3Client({ region: process.env.AWS_REGION });

const streamToBuffer = async (stream) => {
  return new Promise((resolve, reject) => {
    const chunks = [];
    stream.on('data', (chunk) => chunks.push(chunk));
    stream.on('error', reject);
    stream.on('end', () => resolve(Buffer.concat(chunks)));
  });
};

export const handler = async (event, context) => {
  try {
    console.log('Event:', JSON.stringify(event, null, 2));

    for (const record of event.Records) {
      const bucketName = record.s3.bucket.name;
      const objectKey = decodeURIComponent(
        record.s3.object.key.replace(/\+/g, ' ')
      );

      console.log(`Processing: ${objectKey} from bucket: ${bucketName}`);

      if (!objectKey.startsWith('raw/')) {
        console.log(`Skipping: ${objectKey} is not in raw/`);
        continue;
      }

      const fileExtension = objectKey
        .toLowerCase()
        .match(/\.(jpg|jpeg|png|gif|bmp|webp|tiff)$/);
      if (!fileExtension) {
        console.log(`Skipping: ${objectKey} unsupported format`);
        continue;
      }

      try {
        // Download original image
        console.log(`Downloading ${objectKey}...`);
        const getObjectParams = { Bucket: bucketName, Key: objectKey };
        const { Body } = await s3.send(new GetObjectCommand(getObjectParams));
        const originalImage = await streamToBuffer(Body);

        // Generate thumbnail
        console.log(`Creating thumbnail for ${objectKey}...`);
        const thumbnailBuffer = await sharp(originalImage)
          .resize(THUMB_WIDTH, THUMB_HEIGHT, {
            fit: 'inside',
            withoutEnlargement: true,
          })
          .jpeg({ quality: THUMB_QUALITY })
          .toBuffer();

        // Determine thumbnail path
        const originalFileName = objectKey.replace('raw/', '');
        const fileNameWithoutExt = originalFileName.replace(/\.[^/.]+$/, '');
        const thumbnailKey = `thumbs/${fileNameWithoutExt}_thumb.jpg`;

        // Upload thumbnail
        console.log(`Uploading thumbnail to ${thumbnailKey}...`);
        await s3.send(
          new PutObjectCommand({
            Bucket: bucketName,
            Key: thumbnailKey,
            Body: thumbnailBuffer,
            ContentType: 'image/jpeg',
            Metadata: {
              'original-file': objectKey,
              'thumbnail-generated': new Date().toISOString(),
              'thumbnail-size': `${THUMB_WIDTH}x${THUMB_HEIGHT}`,
            },
          })
        );

        console.log(`✅ Successfully created thumbnail: ${thumbnailKey}`);
      } catch (error) {
        console.error(`❌ Error processing ${objectKey}:`, error);
        continue;
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Thumbnail processing completed',
      }),
    };
  } catch (error) {
    console.error('Lambda execution error:', error);
    throw error;
  }
};
