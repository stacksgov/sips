import { c32address } from "c32check";
import bs58check from "bs58check";

const sipNumber = parseInt(process.argv[2], 10);
if (!sipNumber || sipNumber < 1) {
  console.error("Usage: node sip-address.js <sip-number>");
  process.exit(1);
}
const VERSION_SP_MAINNET = 22;

// Always make a 20-byte "hash": [00...00 | ASCII("yes-sip-N"|"no-sip-N")]
function makeHashHex(msg) {
  const ascii = Buffer.from(msg, "ascii"); // explicit ASCII
  if (ascii.length > 20) {
    throw new Error(`Message too long for 20-byte embed: ${msg}`);
  }
  const zeros = 20 - ascii.length;
  return Buffer.concat([Buffer.alloc(zeros, 0x00), ascii]).toString("hex"); // 40 hex chars
}

function btcAddressFromHashHex(hashHex) {
  const payload20 = Buffer.from(hashHex, "hex");
  return bs58check.encode(Buffer.concat([Buffer.from([0x00]), payload20])); // P2PKH mainnet
}

function stacksAddressFromHashHex(hashHex) {
  return c32address(VERSION_SP_MAINNET, hashHex); // expects 40-char hex (20 bytes)
}

const yesMsg = `yes-sip-${sipNumber}`;
const noMsg = `no-sip-${sipNumber}`;

const yesHashHex = makeHashHex(yesMsg);
const noHashHex = makeHashHex(noMsg);

const yesBTC = btcAddressFromHashHex(yesHashHex);
const noBTC = btcAddressFromHashHex(noHashHex);

const yesSTX = stacksAddressFromHashHex(yesHashHex);
const noSTX = stacksAddressFromHashHex(noHashHex);

console.log({
  sipNumber,
  yesMsg,
  noMsg,
  yesAsciiHex: Buffer.from(yesMsg, "ascii").toString("hex"),
  noAsciiHex: Buffer.from(noMsg, "ascii").toString("hex"),
  yesHashHex,
  noHashHex,
  yesBTC,
  noBTC,
  yesSTX,
  noSTX,
});
