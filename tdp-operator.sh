ssh ubuntu@ec2-52-90-1-148.compute-1.amazonaws.com -i operator/keys/tdp-operator-keypair.pem -L 3000:localhost:3000 -L 39339:localhost:39339 -L 36027:localhost:36027
