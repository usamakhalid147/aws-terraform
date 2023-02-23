import boto3
import datetime

excluded_users = ["jenkins", "user2", "user3"]

def lambda_handler(event, context):
    iam = boto3.client("iam")
    now = datetime.datetime.now(datetime.timezone.utc)
    max_age = datetime.timedelta(days=90)

    # Get all IAM users
    users = iam.list_users()
    for user in users["Users"]:
        if user["UserName"] not in excluded_users:
            # Get access keys for each user
            access_keys = iam.list_access_keys(UserName=user["UserName"])
            for access_key in access_keys["AccessKeyMetadata"]:
                # Get creation date of access key
                key_id = access_key["AccessKeyId"]
                creation_date = access_key["CreateDate"]

                # Calculate age of access key
                age = now - creation_date
                if age >= max_age:
                    # Deactivate access key if it is older than 90 days
                    iam.update_access_key(UserName=user["UserName"], AccessKeyId=key_id, Status="Inactive")
                    print(f"Deactivated access key {key_id} for user {user['UserName']}")

    return "Access keys checked and updated."