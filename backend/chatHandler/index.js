// Chat handler: process user messages and return AI-generated reply
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();
const OpenAI = require('openai');

// Fetch API key from Secrets Manager
async function getOpenAIKey() {
  const data = await secretsManager.getSecretValue({ SecretId: 'prod/openai/api_key' }).promise();
  // SecretString may be raw or JSON
  if (data.SecretString) {
    try {
      const parsed = JSON.parse(data.SecretString);
      return parsed.OPENAI_API_KEY || parsed.openai_api_key;
    } catch {
      return data.SecretString;
    }
  }
  throw new Error('OpenAI API key not found in Secrets Manager');
}

exports.handler = async (event) => {
  // Parse incoming chat message
  const body = JSON.parse(event.body || '{}');
  const userMessage = body.message || '';

  // Retrieve API key and initialize OpenAI client
  const openaiKey = await getOpenAIKey();
  const openai = new OpenAI({ apiKey: openaiKey });

  // Send messages to model
  const response = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      { role: 'system', content: 'You are a helpful tee-time booking assistant.' },
      { role: 'user', content: userMessage }
    ]
  });

  // Return chat reply
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reply: response.choices[0].message.content })
  };
};