#!/bin/bash

# Check if required arguments are provided
if [ $# -lt 2 ]; then
  echo "Usage: $0 <aws-secret-name> <ec2-endpoint>"
  echo "Example: $0 my-ec2-key ec2-12-34-56-78.compute-1.amazonaws.com ec2-user"
  exit 1
fi

# Assign arguments to variables
SECRET_NAME=$1
EC2_ENDPOINT=$2
SSH_USER=ec2-user # use default user

# Create a temporary key file
KEY_FILE="$HOME/.ssh/temp_key_$(date +%s).pem"

echo "Retrieving key from AWS Secrets Manager..."
aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query SecretString --output text >"$KEY_FILE"

if [ $? -ne 0 ]; then
  echo "Failed to retrieve the key from AWS Secrets Manager"
  exit 1
fi

# Set proper permissions
chmod 600 "$KEY_FILE"
echo "Key saved to $KEY_FILE with proper permissions"

# Open in vim if requested
if [ "$4" == "--edit" ] || [ "$4" == "-e" ]; then
  vim "$KEY_FILE"
fi

# Display SSH command
echo ""
echo "To SSH into the instance, run:"
echo "ssh -i \"$KEY_FILE\" $SSH_USER@$EC2_ENDPOINT"

# Optionally, offer to connect directly
echo ""
read -p "Connect now? (y/n): " CONNECT
if [[ "$CONNECT" =~ ^[Yy]$ ]]; then
  ssh -i "$KEY_FILE" "$SSH_USER@$EC2_ENDPOINT"
fi

echo ""
echo "Remember to delete the key file when you're done: rm \"$KEY_FILE\""
