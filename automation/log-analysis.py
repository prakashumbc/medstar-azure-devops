import requests
import json
import csv
import datetime
import smtplib
from email.mime.text import MIMEText

# Azure API Endpoint (Replace YOUR_SUBSCRIPTION_ID)
AZURE_LOGS_URL = "https://management.azure.com/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/MedStar-RG/providers/Microsoft.Insights/eventTypes/management/values?api-version=2015-04-01"

# Replace with your Azure Bearer Token
HEADERS = {
    "Authorization": "Bearer YOUR_ACCESS_TOKEN",
    "Content-Type": "application/json"
}

# Fetch Logs from Azure
def fetch_logs():
    response = requests.get(AZURE_LOGS_URL, headers=HEADERS)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Failed to retrieve logs. Status Code: {response.status_code}")
        return None

# Process Logs
def process_logs(log_data):
    error_logs = []
    security_alerts = []

    for log in log_data.get('value', []):
        log_entry = {
            "timestamp": log['properties']['eventTimestamp'],
            "resource": log['properties']['resourceId'],
            "status": log['properties']['status'],
            "operationName": log['properties']['operationName']
        }

        # Check for errors
        if "error" in log_entry['status'].lower():
            error_logs.append(log_entry)

        # Check for security issues
        if "security" in log_entry['operationName'].lower():
            security_alerts.append(log_entry)

    return error_logs, security_alerts

# Save logs to JSON
def save_logs_json(error_logs, security_alerts):
    with open("error_logs.json", "w") as json_file:
        json.dump(error_logs, json_file, indent=4)
    with open("security_alerts.json", "w") as json_file:
        json.dump(security_alerts, json_file, indent=4)
    print("✅ Logs saved to JSON.")

# Save logs to CSV
def save_logs_csv(error_logs, filename):
    keys = error_logs[0].keys() if error_logs else ["timestamp", "resource", "status", "operationName"]
    with open(filename, "w", newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=keys)
        writer.writeheader()
        writer.writerows(error_logs)
    print(f"✅ Logs saved to CSV: {filename}")

# Send Email Alert
def send_email_alert(error_logs):
    if not error_logs:
        return

    sender_email = "your-email@example.com"
    recipient_email = "admin@example.com"
    subject = "Azure Log Analysis Alert"
    body = f"🚨 {len(error_logs)} Errors Detected in Azure Logs!\n\n"
    
    for log in error_logs:
        body += f"🔴 {log['timestamp']} - {log['resource']} - {log['status']}\n"

    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = sender_email
    msg["To"] = recipient_email

    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.starttls()
        server.login(sender_email, "YOUR_PASSWORD")
        server.sendmail(sender_email, recipient_email, msg.as_string())

    print("✅ Email alert sent!")

# Run the script
if __name__ == "__main__":
    logs = fetch_logs()
    if logs:
        error_logs, security_alerts = process_logs(logs)
        save_logs_json(error_logs, security_alerts)
        save_logs_csv(error_logs, "error_logs.csv")
        send_email_alert(error_logs)
    else:
        print("No logs retrieved.")
