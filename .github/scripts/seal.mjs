// Encrypts a file so that only the holder of the private key matching <pubkey.pem> can read it.
// That key never leaves the maintainer's Mac, where ~/.invade-ci/open-logs.mjs opens these files.
//
//   node seal.mjs <in> <out> <pubkey.pem>
//
// AES-256-GCM with a random 32-byte key and a random 12-byte IV; the key is wrapped with RSA-OAEP
// (SHA-256). Output format:
//   "ICL1" | u16be wrapped-key length | wrapped key | IV (12 bytes) | tag (16 bytes) | ciphertext
// No dependencies: node:crypto and node:fs only.
import { constants, createCipheriv, publicEncrypt, randomBytes } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'

const [input, output, publicKeyPath] = process.argv.slice(2)
if (!input || !output || !publicKeyPath) {
  console.error('usage: node seal.mjs <in> <out> <pubkey.pem>')
  process.exit(2)
}

const key = randomBytes(32)
const iv = randomBytes(12)
const cipher = createCipheriv('aes-256-gcm', key, iv)
const ciphertext = Buffer.concat([cipher.update(readFileSync(input)), cipher.final()])
const tag = cipher.getAuthTag()
const wrappedKey = publicEncrypt(
  { key: readFileSync(publicKeyPath, 'utf8'), padding: constants.RSA_PKCS1_OAEP_PADDING, oaepHash: 'sha256' },
  key,
)
key.fill(0)

const header = Buffer.alloc(6)
header.write('ICL1', 0, 'latin1')
header.writeUInt16BE(wrappedKey.length, 4)
writeFileSync(output, Buffer.concat([header, wrappedKey, iv, tag, ciphertext]))
