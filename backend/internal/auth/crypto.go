package auth

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
)

var cachedPubKey *rsa.PublicKey

func SetPubKey(pemText string) error {
	block, _ := pem.Decode([]byte(pemText))
	if block == nil {
		return nil
	}
	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return err
	}
	cachedPubKey = pub.(*rsa.PublicKey)
	return nil
}

func GetPubKey() *rsa.PublicKey { return cachedPubKey }

func EncryptPassword(plaintext string) (string, error) {
	if cachedPubKey == nil {
		return "", nil
	}
	ct, err := rsa.EncryptPKCS1v15(rand.Reader, cachedPubKey, []byte(plaintext))
	if err != nil {
		return "", err
	}
	return "__RSA__" + base64.StdEncoding.EncodeToString(ct), nil
}

// unused; kept for potential SHA1-based key identification
var _ = sha1.New
