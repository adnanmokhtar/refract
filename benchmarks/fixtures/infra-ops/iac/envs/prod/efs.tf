# Shared media library (mounted by media-processor through the efs-sc StorageClass).
resource "aws_efs_file_system" "media" {
  creation_token = "larder-media"
  encrypted      = true
  kms_key_id     = aws_kms_key.data.arn
}
