variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "name" {
  type    = string
  default = "llm-platform"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_type" {
  description = "CPU inference: 8 vCPU fits two 3-core llama.cpp replicas per node"
  type        = string
  default     = "c7i.2xlarge"
}

variable "node_max_size" {
  type    = number
  default = 2
}
