// Booking handler: save booking and send confirmation
const AWS = require('aws-sdk');
const dynamo = new AWS.DynamoDB.DocumentClient();
const ses = new AWS.SES();
const { v4: uuidv4 } = require('uuid');

exports.handler = async (event) => {
  const { courseId, date, time, email } = JSON.parse(event.body);
  const bookingId = uuidv4();
  // Save booking
  await dynamo.put({
    TableName: 'Bookings',
    Item: { bookingId, courseId, date, time, email }
  }).promise();

  // Send confirmation email
  await ses.sendEmail({
    Source: process.env.SES_FROM_ADDRESS,
    Destination: { ToAddresses: [email] },
    Message: {
      Subject: { Data: 'Tee Time Booked' },
      Body: {
        Text: {
          Data: `Your tee time at course ${courseId} is booked for ${date} at ${time}.`
        }
      }
    }
  }).promise();

  return {
    statusCode: 200,
    body: JSON.stringify({ bookingId })
  };
};