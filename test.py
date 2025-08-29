import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding

PUB_PEM = b"""-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2u2v/bjSIVsaxCBBxkjWf7LpmsjuhFJUJE7MYTn9hBcDXlK4smgtNoMqmGz4ztg5t1h+h0fqrJT3WkdoLV/FKC8OwElTe+p+YLqA6/PgmGtsffcQmAW0eye5NygiWM+B0tO69ML6jNLpAWAvXwod5kr/k7qsM1DGTux+e7bjdFz/IA8vOZx3IlGHnX+RE/uBJUwPXHnLPw5pQSwkWwfpPwxMrgzwik6htqRHF2c7Z+pJToXbrIJWD5nmRiU6jzgu8ncLqbMb3WNOKSodcEnlUpTH/ApH56IOJHWpq3mxJL9DaUaWzjziR93wjlyvR1K4VM7TLqD35CVZQaoE5FWgZwIDAQAB
-----END PUBLIC KEY-----"""

def encrypt_jsencrypt(plaintext: str) -> str:
    pub = serialization.load_pem_public_key(PUB_PEM)
    ct = pub.encrypt(plaintext.encode("utf-8"), padding.PKCS1v15())
    return "__RSA__" + base64.b64encode(ct).decode()

if __name__ == "__main__":
    print(encrypt_jsencrypt("hz.xjtu.123"))