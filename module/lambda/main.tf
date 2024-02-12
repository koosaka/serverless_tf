# 以下はregistryのmoduleを利用する場合
# module "lambda" {
#   source  = "terraform-aws-modules/lambda/aws"
#   version = "7.2.1"
# }

// ラムダがロールを利用するを可能にする許可ポリシー
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


# ラムダにアタッチするIAMロール
resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

// lambdaのbuild
resource "null_resource" "lambda_build" {
  triggers = {
    code_diff = join("", [
      for file in fileset(local.functions_codedir_local_path, "{*.ts, package*.json}")
      : filebase64("${local.functions_codedir_local_path}/${file}")
    ])
  }

  provisioner "local-exec" {
    command = "cd ${local.functions_codedir_local_path} && npm install"
  }
  provisioner "local-exec" {
    command = "cd ${local.functions_codedir_local_path} && npm run build"
  }
}

data "archive_file" "lambda" {
  depends_on = [null_resource.lambda_build]
  for_each    = local.lambda_fuctions
  type        = "zip"
  source_file = "${local.functions_codedir_local_path}/dist/${each.key}/index.js" // 変更箇所
  output_path = "${local.functions_codedir_local_path}/dist/${each.key}/index.zip"
}

resource "aws_lambda_function" "lambda_function" {
  depends_on = [ data.archive_file.lambda ]
  for_each = local.lambda_fuctions
  filename      = "${local.functions_codedir_local_path}/dist/${each.key}/index.zip"
  function_name = each.value.name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"

  source_code_hash = data.archive_file.lambda["${each.key}"].output_base64sha256

  runtime = "nodejs18.x"

  environment {
    variables = {
      foo = "bar"
    }
  }
}