import twilio from 'twilio';

const client = twilio();
export const send = (to, body) => client.messages.create({ body, to, from: '+15550000000' });
