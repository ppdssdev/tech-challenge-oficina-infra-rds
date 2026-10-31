variable "environment" {
  description = "Ambiente futuro, isolado por stack e state."
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Use staging ou production."
  }
}

variable "aws_region" {
  description = "Região autorizada para a futura implementação."
  type        = string
  default     = "us-east-2"
  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "Somente us-east-2."
  }
}
