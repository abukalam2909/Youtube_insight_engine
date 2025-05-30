output "api_base_url" {
  value = "${aws_apigatewayv2_api.http_api.api_endpoint}"
}

output "frontend_website_url" {
  value = aws_s3_bucket_website_configuration.frontend_ui.website_endpoint
}