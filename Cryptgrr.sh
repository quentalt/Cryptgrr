#!/bin/bash

# Minimum password length
MIN_PASSWORD_LENGTH=8

# Function to display usage
usage() {
    echo "Usage: $0 -e|-d -i input_file -o output_file [-m mode] [-l log_file]"
    echo "  -e             Encrypt the file"
    echo "  -d             Decrypt the file"
    echo "  -i input_file  Specify the input file"
    echo "  -o output_file Specify the output file"
    echo "  -m mode        Specify the encryption mode (e.g., aes-256-cbc)"
    echo "  -l log_file    Specify a log file (optional)"
    echo "  -h             Display this help message"
    exit 1
}

# Function to prompt for a password securely
prompt_password() {
    local prompt=$1
    echo -n "$prompt: "
    stty -echo
    read password
    stty echo
    echo
}

# Function to confirm the password
confirm_password() {
    while true; do
        prompt_password "Enter password (minimum $MIN_PASSWORD_LENGTH characters)"
        if [ ${#password} -lt $MIN_PASSWORD_LENGTH ]; then
            echo "Password must be at least $MIN_PASSWORD_LENGTH characters long. Try again."
            continue
        fi
        local password1=$password
        prompt_password "Confirm password"
        local password2=$password

        if [ "$password1" != "$password2" ]; then
            echo "Passwords do not match. Try again."
        else
            password=$password1
            break
        fi
    done
}

# Function to log messages to a log file
log_message() {
    local message=$1
    if [ -n "$log_file" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
    fi
}

# Function to handle cleanup on exit
cleanup() {
    stty echo
    echo "Cleaning up..."
    exit 1
}

# Trap signals for cleanup
trap cleanup INT TERM ERR

# Parse command-line arguments
while getopts ":edi:o:m:l:h" opt; do
  case $opt in
    e)
      action="encrypt"
      ;;
    d)
      action="decrypt"
      ;;
    i)
      input_file=$OPTARG
      ;;
    o)
      output_file=$OPTARG
      ;;
    m)
      mode=$OPTARG
      ;;
    l)
      log_file=$OPTARG
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

# Check if all required arguments are provided
if [ -z "$action" ] || [ -z "$input_file" ] || [ -z "$output_file" ]; then
    usage
fi

# Set default mode if not provided
if [ -z "$mode" ]; then
    mode="aes-256-cbc"
fi

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file does not exist: $input_file"
    log_message "Error: Input file does not exist: $input_file"
    exit 3
fi

# Check if the output file already exists
if [ -f "$output_file" ]; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        read -p "Output file already exists. Overwrite? (y/n): " choice
    else
        read -r -p "Output file already exists. Overwrite? (y/n): " choice
    fi
    case "$choice" in
      y|Y ) ;;
      * ) echo "Operation aborted."
          log_message "Operation aborted by user."
          exit 4
          ;;
    esac
fi

# Prompt for the password
if [ "$action" == "encrypt" ]; then
    confirm_password
else
    prompt_password "Enter password"
fi

# Encrypt or Decrypt the file based on the action
if [ "$action" == "encrypt" ]; then
    openssl enc -"$mode" -salt -in "$input_file" -out "$output_file" -pass pass:"$password" -pbkdf2
    if [ $? -eq 0 ]; then
        echo "File encrypted successfully: $output_file"
        log_message "File encrypted successfully: $output_file"
    else
        echo "Error encrypting file"
        log_message "Error encrypting file: $input_file"
        exit 5
    fi
elif [ "$action" == "decrypt" ]; then
    openssl enc -d -"$mode" -in "$input_file" -out "$output_file" -pass pass:"$password" -pbkdf2
    if [ $? -eq 0 ]; then
        echo "File decrypted successfully: $output_file"
        log_message "File decrypted successfully: $output_file"
    else
        echo "Error decrypting file"
        log_message "Error decrypting file: $input_file"
        exit 6
    fi
else
    usage
fi

# Cleanup
trap - INT TERM ERR
stty echo
