// Search handler: look up courses by ZIP, date, and criteria
const AWS = require('aws-sdk');
const dynamo = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const { zip, date, criteria } = JSON.parse(event.body || '{}');
  const params = {
    TableName: 'GolfCourses',
    IndexName: 'ZipIndex',
    KeyConditionExpression: 'zip = :z',
    ExpressionAttributeValues: { ':z': zip }
  };
  const result = await dynamo.query(params).promise();
  // TODO: filter by date and criteria
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ courses: result.Items || [] })
  };
};