import json
import boto3
import os
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
BUCKET = os.environ.get('S3_BUCKET', '')


def handler(event, context):
    """
    Lambda de traitement serverless pour Pritunl HA.
    Exemples d'usage :
      - Sauvegarder la config Pritunl vers S3
      - Notifier lors d'un changement d'état ASG
      - Exporter des logs VPN
    """
    logger.info(f"Event received: {json.dumps(event)}")

    action = event.get('action', 'backup')

    if action == 'backup':
        return handle_backup(event)
    elif action == 'restore':
        return handle_restore(event)
    elif action == 'asg_lifecycle':
        return handle_asg_lifecycle(event)
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Unknown action: {action}'})
        }


def handle_backup(event):
    """Sauvegarde une config dans S3."""
    config_data = event.get('config', {})
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
    key = f"backups/pritunl-config-{timestamp}.json"

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=json.dumps(config_data),
        ContentType='application/json'
    )

    logger.info(f"Config backed up to s3://{BUCKET}/{key}")
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Backup successful', 'key': key})
    }


def handle_restore(event):
    """Restaure la dernière config depuis S3."""
    response = s3.list_objects_v2(Bucket=BUCKET, Prefix='backups/', MaxKeys=10)
    objects = sorted(
        response.get('Contents', []),
        key=lambda x: x['LastModified'],
        reverse=True
    )

    if not objects:
        return {'statusCode': 404, 'body': json.dumps({'error': 'No backup found'})}

    latest = objects[0]['Key']
    obj = s3.get_object(Bucket=BUCKET, Key=latest)
    config = json.loads(obj['Body'].read())

    logger.info(f"Restored config from s3://{BUCKET}/{latest}")
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Restore successful', 'config': config})
    }


def handle_asg_lifecycle(event):
    """Traite les événements de cycle de vie ASG."""
    instance_id = event.get('instance_id', 'unknown')
    lifecycle_action = event.get('lifecycle_action', 'LAUNCHING')

    logger.info(f"ASG lifecycle: instance={instance_id}, action={lifecycle_action}")

    # Logique métier : enregistrer l'événement dans S3
    log_key = f"asg-events/{datetime.utcnow().strftime('%Y%m%d')}/{instance_id}.json"
    s3.put_object(
        Bucket=BUCKET,
        Key=log_key,
        Body=json.dumps({'instance_id': instance_id, 'action': lifecycle_action}),
        ContentType='application/json'
    )

    return {
        'statusCode': 200,
        'body': json.dumps({'message': f'ASG lifecycle {lifecycle_action} processed'})
    }
