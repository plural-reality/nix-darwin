#!/usr/bin/env python3
# Decrypt Chrome (Profile 5) の _note_session_v5 Cookie を平文にする。
# 使い方(MBA上): CHROME_KEY=$(security find-generic-password -w -s "Chrome Safe Storage") \
#                 python3 decrypt-note-cookie.py
# 事前に `security unlock-keychain ~/Library/Keychains/login.keychain-db` が要ることがある。
# 出力の VAL32 が Playwright に addCookies する値。
import subprocess, hashlib, os, sqlite3, shutil, binascii
key_pw = os.environ['CHROME_KEY'].encode()
home = os.path.expanduser('~')
src = f'{home}/Library/Application Support/Google/Chrome/Profile 5/Cookies'
tmp = '/tmp/note_cookies.sqlite'
shutil.copy2(src, tmp)                       # Chrome がロックしているので copy
aes_key = hashlib.pbkdf2_hmac('sha1', key_pw, b'saltysalt', 1003, 16)
con = sqlite3.connect(tmp)
row = con.execute(
    "SELECT encrypted_value FROM cookies WHERE host_key LIKE '%note.com%' AND name='_note_session_v5'"
).fetchone()
con.close()
enc = row[0]
assert enc[:3] == b'v10', enc[:3]
ct = enc[3:]
keyhex = binascii.hexlify(aes_key).decode()
ivhex = binascii.hexlify(b' ' * 16).decode()
p = subprocess.run(
    ['openssl', 'enc', '-aes-128-cbc', '-d', '-K', keyhex, '-iv', ivhex, '-nopad'],
    input=ct, capture_output=True)
dec = p.stdout
if dec:
    pad = dec[-1]
    if 1 <= pad <= 16:
        dec = dec[:-pad]
# 新しめの macOS Chrome は先頭32byteに sha256 domain prefix を付ける
print('VAL32=' + dec[32:].decode('utf-8', 'replace'))
