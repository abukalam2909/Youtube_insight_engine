# resource "aws_opensearch_domain" "youtube_comments" {
#   domain_name    = "youtube-comments"
#   engine_version = "OpenSearch_2.11"

#   cluster_config {
#     instance_type  = "t3.small.search"
#     instance_count = 1
#   }

#   ebs_options {
#     ebs_enabled = true
#     volume_size = 10
#     volume_type = "gp3"
#   }

#   access_policies = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect   = "Allow",
#         Principal = {
#           AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
#         },
#         Action   = "es:*",
#         Resource = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/youtube-comments/*"
#       }
#     ]
#   })

#   node_to_node_encryption {
#     enabled = true
#   }

#   advanced_security_options {
#     enabled                        = true
#     internal_user_database_enabled = true

#     master_user_options {
#         master_user_name     = "admin"
#         master_user_password = "StrongPassword123!"
#     }
#   }


#   tags = {
#     Name = "YouTube Comments OpenSearch"
#   }
# }


# resource "null_resource" "create_knn_index" {
#   depends_on = [aws_opensearch_domain.youtube_comments]

#   provisioner "local-exec" {
#     command = <<EOT
#     awscurl \
#       --service es \
#       --region ${var.aws_region} \
#       -XPUT "https://${aws_opensearch_domain.youtube_comments.endpoint}/youtube-comments" \
#       -H "Content-Type: application/json" \
#       -d '{
#         "settings": {
#           "index": {
#             "knn": true
#           }
#         },
#         "mappings": {
#           "properties": {
#             "video_id": { "type": "keyword" },
#             "title": { "type": "text" },
#             "comment": { "type": "text" },
#             "comment_embedding": {
#               "type": "knn_vector",
#               "dimension": 1536
#             }
#           }
#         }
#       }'
#     EOT
#   }
# }


