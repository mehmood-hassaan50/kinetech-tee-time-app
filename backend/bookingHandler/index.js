const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();
const sgMail = require('@sendgrid/mail');
const { v4: uuidv4 } = require('uuid');

async function getSendGridKey() {
  const data = await secretsManager
    .getSecretValue({ SecretId: 'prod/sendgrid/api_key' })
    .promise();
  let secret = data.SecretString;
  try {
    const parsed = JSON.parse(secret);
    return parsed.SENDGRID_API_KEY;
  } catch {
    return secret;
  }
}

exports.handler = async (event) => {
  const { courseId, date, time, email } = JSON.parse(event.body);
  const bookingId = uuidv4();

  // Save booking (same as before)
  const dynamo = new AWS.DynamoDB.DocumentClient();
  await dynamo.put({
    TableName: 'Bookings',
    Item: { bookingId, courseId, date, time, email }
  }).promise();

  // Send confirmation via SendGrid
  const apiKey = await getSendGridKey();
  sgMail.setApiKey(apiKey);
  await sgMail.send({
    to: email,
    from: 'hassaan.mehmood@kinetechcloud.com', // must be a verified sender in SendGrid
    subject: 'Tee Time Booked',
    text: `Your tee time at course ${courseId} is booked for ${date} at ${time}.`
  });

  return {
    statusCode: 200,
    body: JSON.stringify({ bookingId })
  };
};
