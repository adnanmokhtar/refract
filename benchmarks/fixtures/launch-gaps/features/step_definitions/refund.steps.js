const assert = require('node:assert/strict');
const { Given, When, Then } = require('@cucumber/cucumber');

Given('a signed-in merchant', async function () {
  this.session = await this.api.signIn('merchant@example.com');
});

Given('a paid order with {int} lines', async function (lines) {
  this.order = await this.api.paidOrder(lines);
});

When('the merchant refunds {int} line', async function (count) {
  this.refund = await this.api.refund(this.order.id, this.order.lines.slice(0, count));
});

Then('the order status is {string}', async function (status) {
  const order = await this.api.order(this.order.id);
  assert.equal(order.status, status);
});

Given('a gold loyalty member', async function () {
  this.customer = await this.api.customer({ tier: 'gold' });
});
