variable "region"              { }
variable "name"                { }
variable "custom_policy"       { default = [] }
variable "policy_attachment"   { default = [] }

resource "aws_iam_role" "task_role_arn" {
  name = "${var.name}-ecs-service-taskrole-fargate"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
            "Service": [
                "s3.amazonaws.com",
                "lambda.amazonaws.com",
                "ecs.amazonaws.com",
                "batch.amazonaws.com",
                "ecs-tasks.amazonaws.com"
            ]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "access_policy" {
  name = "${var.name}-ecs-task-policy-access_policy_fargate"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Sid": "Stmt1532966429082",
        "Action": [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::*"
    },
    {
        "Sid": "Stmt1532967608746",
        "Action": "lambda:*",
        "Effect": "Allow",
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ],
            "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ],
            "Resource": "*"
    },
    {
        "Sid": "XRayDaemonWriteAccess",
        "Effect": "Allow",
        "Action": [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords",
            "xray:GetSamplingRules",
            "xray:GetSamplingTargets",
            "xray:GetSamplingStatisticSummaries"
        ],
        "Resource": [
            "*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "xray:GetSamplingRules",
            "xray:GetSamplingTargets",
            "xray:GetSamplingStatisticSummaries",
            "xray:BatchGetTraces",
            "xray:GetServiceGraph",
            "xray:GetTraceGraph",
            "xray:GetTraceSummaries",
            "xray:GetGroups",
            "xray:GetGroup",
            "xray:GetTimeSeriesServiceStatistics",
            "xray:GetInsightSummaries",
            "xray:GetInsight",
            "xray:GetInsightEvents",
            "xray:GetInsightImpactGraph"
        ],
        "Resource": [
            "*"
        ]
    },
    {
      "Sid": "EFSWriteRead",
      "Effect": "Allow",
      "Action": [
          "elasticfilesystem:Client*"
      ],
      "Resource": [
          "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task-role-attach" {
    role       = aws_iam_role.task_role_arn.name
    policy_arn = aws_iam_policy.access_policy.arn
}

#https://docs.amazonaws.cn/en_us/AmazonECS/latest/developerguide/task_execution_IAM_role.html, if not exists create
data "aws_iam_policy_document" "ecs_tasks_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}


resource "aws_iam_policy" "access_policy_task_execution_role" {
  name = "${var.name}-ecs-task-exec-role-access_policy_fargate"

   policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [    
        {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
        "Effect": "Allow",
            "Action": [
                "ssm:GetParameters",
                "secretsmanager:GetSecretValue",
                "kms:Decrypt"
            ],
            "Resource": [
                "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/*",
                "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"
            ]
        },
        {
        "Effect": "Allow",
            "Action": [
                "application-autoscaling:*",
                "ecs:DescribeServices",
                "ecs:UpdateService",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:DescribeAlarmHistory",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:DescribeAlarmsForMetric",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DisableAlarmActions",
                "cloudwatch:EnableAlarmActions",
                "iam:CreateServiceLinkedRole",
                "sns:CreateTopic",
                "sns:Subscribe",
                "sns:Get*",
                "sns:List*",
                "elasticfilesystem:Client*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}


resource "aws_iam_role" "ecs_tasks_execution_role" {
  name               = "${var.name}-ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role" {
  role       = aws_iam_role.ecs_tasks_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role_2" {
  role       = aws_iam_role.ecs_tasks_execution_role.name
  policy_arn = aws_iam_policy.access_policy_task_execution_role.arn
}


resource "aws_iam_policy" "custom_policy" {
  count = length(var.custom_policy) > 0 ? length(var.custom_policy) : 0

  name = "${var.name}-${lookup(element(var.custom_policy, count.index), "name")}"

  policy = jsonencode(lookup(element(var.custom_policy, count.index), "policy"))
}

resource "aws_iam_role_policy_attachment" "custom_attchment" {
  count = length(var.custom_policy) > 0 ? length(var.custom_policy) : 0

  role       = aws_iam_role.task_role_arn.name
  policy_arn = element(aws_iam_policy.custom_policy.*.arn, count.index)
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  count = length(var.policy_attachment) > 0 ? length(var.policy_attachment) : 0

  role       = aws_iam_role.task_role_arn.name
  policy_arn = element(var.policy_attachment, count.index)
}

output "ecs_task_role" { value = "${aws_iam_role.task_role_arn.arn}" }
output "ecs_task_exec_role" { value = "${aws_iam_role.ecs_tasks_execution_role.arn}" }
