#!/bin/bash

my_backstage=my-backstage

aws configure set default.region us-east-1

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

if test -f cf-stack.yaml; then
    rm cf-stack.yaml
fi

cat <<EOF | tee cf-stack.yaml
AWSTemplateFormatVersion: 2010-09-09
Description: "Creates a Linux operator machine."
Metadata:
  Backstage:
    Entities:
      - apiVersion: backstage.io/v1alpha1
        kind: Component
        metadata:
          name: petstore
          namespace: external-systems
          description: Petstore
        spec:
          type: service
          lifecycle: experimental
          owner: 'group:pet-managers'
          providesApis:
            - petstore
            - internal/streetlights
            - hello-world
      - apiVersion: backstage.io/v1alpha1
        kind: API
        metadata:
          name: petstore
          description: The Petstore API
        spec:
          type: openapi
          lifecycle: production
          owner: petstore@example.com
          definition:
            \$text: 'https://petstore.swagger.io/v2/swagger.json'
Mappings:
  Images:
    us-east-1:
      Id: "ami-04505e74c0741db8d"
Resources:
  OperatorKeyPair:
    Type: 'AWS::EC2::KeyPair'
    Properties:
      KeyName: backstage-operator-keypair
  OperatorSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      VpcId: vpc-0616056f55547657e
      GroupDescription: Security Group for AMIs
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
  OperatorInstance:
    Type: "AWS::EC2::Instance"
    Properties:
      ImageId: !FindInMap
        - Images
        - !Ref AWS::Region
        - Id
      InstanceType: "t3.large"
      KeyName: !Ref OperatorKeyPair
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 50
            DeleteOnTermination: true
      SecurityGroupIds:
        - !Ref OperatorSecurityGroup
      Tags:
        - Key: "Name"
          Value: "backstage-operator"
Outputs:
  InstanceId:
    Value: !Ref OperatorInstance
  PublicDnsName:
    Value: !GetAtt OperatorInstance.PublicDnsName
EOF

aws cloudformation create-stack --stack-name backstage-stack --region $AWS_REGION \
    --template-body file:///home/ubuntu/cf-stack.yaml
aws cloudformation wait stack-create-complete --stack-name backstage-stack --region $AWS_REGION


# From your Backstage root directory
cd ${my_backstage}/packages/backend
yarn add backstage-aws-cloudformation-plugin

cd ~

# Add the CloudFormationRegionProcessor and CloudFormationStackProcessor processors your catalog builder
rm ${my_backstage}/packages/backend/src/plugins/catalog.ts

cat <<EOF | tee ${my_backstage}/packages/backend/src/plugins/catalog.ts
import { CatalogBuilder } from '@backstage/plugin-catalog-backend';
import { ScaffolderEntitiesProcessor } from '@backstage/plugin-scaffolder-backend';
import { Router } from 'express';
import { PluginEnvironment } from '../types';
import { CloudFormationRegionProcessor, CloudFormationStackProcessor } from 'backstage-aws-cloudformation-plugin';

export default async function createPlugin(
  env: PluginEnvironment,
): Promise<Router> {
  const builder = await CatalogBuilder.create(env);
  builder.addProcessor(new ScaffolderEntitiesProcessor());
  builder.addProcessor(new CloudFormationStackProcessor(env.config));
  builder.addProcessor(new CloudFormationRegionProcessor(env.config));
  const { processingEngine, router, entitiesCatalog, locationsCatalog, locationService, locationAnalyzer } = await builder.build();
  await processingEngine.start();
  return router;
}
EOF

git clone https://github.com/purple-technology/backstage-aws-cloudformation-plugin.git

# ADD THE FOLLOWING THREE LINES TO THE SCRIPTS SECTION IN THE NEXT VIM
rm backstage-aws-cloudformation-plugin/package.json

cat <<EOF | tee backstage-aws-cloudformation-plugin/package.json
{
        "name": "backstage-aws-cloudformation-plugin",
        "version": "2.0.10",
        "contributors": [
                "Filip Pyrek <PyrekFilip@gmail.com> (https://filip.pyrek.cz)"
        ],
        "description": "Backstage plugin for using AWS CloudFormation as source location",
        "license": "MIT",
        "main": "./dist/index.js",
        "types": "./dist/index.d.ts",
        "engines": {
                "node": ">= 12.4.0"
        },
        "scripts": {
                "test": "jest --forceExit --detectOpenHandles",
                "tdd": "npm run test -- --watch",
                "build": "rm -rf dist && tsc",
                "lint": "eslint . --ext .js,.jsx,.ts,.tsx",
                "prepare": "husky install",
                "release": "standard-version",
                "dev": "AWS_SDK_LOAD_CONFIG=true concurrently \"yarn start\" \"yarn start-backend\"",
                "start": "AWS_SDK_LOAD_CONFIG=true yarn workspace app start",
                "start-backend": "AWS_SDK_LOAD_CONFIG=true yarn workspace backend start"
        },
        "devDependencies": {
                "@backstage/catalog-model": "^1.0.0",
                "@backstage/config": "^1.0.0",
                "@backstage/plugin-catalog-backend": "^1.0.0",
                "@commitlint/cli": "^16.2.1",
                "@commitlint/config-conventional": "^16.2.1",
                "@types/jest": "^27.4.1",
                "@types/node": "^14.14.31",
                "@typescript-eslint/eslint-plugin": "^5.15.0",
                "@typescript-eslint/parser": "^5.15.0",
                "aws-sdk-mock": "^5.6.2",
                "eslint-config-prettier": "^8.5.0",
                "eslint-plugin-prettier": "^4.0.0",
                "eslint-plugin-simple-import-sort": "^7.0.0",
                "eslint": "^7.32.0",
                "husky": "^7.0.4",
                "jest": "^27.5.1",
                "prettier": "^2.5.1",
                "standard-version": "^9.3.2",
                "ts-jest": "^27.1.3",
                "typescript": "^4.6.2"
        },
        "lint-staged": {
                "*.{ts,js,json}": "eslint --fix"
        },
        "dependencies": {
                "aws-sdk": "^2.977.0",
                "find-and-replace-anything": "^2.2.2"
        },
        "peerDependencies": {
                "@backstage/catalog-model": "1.x",
                "@backstage/config": "1.x",
                "@backstage/plugin-catalog-backend": "1.x"
        },
        "homepage": "https://github.com/purple-technology/backstage-aws-cloudformation-plugin#readme",
        "repository": {
                "type": "git",
                "url": "git+https://github.com/purple-technology/backstage-aws-cloudformation-plugin.git"
        },
        "bugs": {
                "url": "https://github.com/purple-technology/backstage-aws-cloudformation-plugin/issues"
        },
        "keywords": [
                "backstage",
                "aws",
                "cloudformation",
                "serverless"
        ],
        "files": [
                "dist"
        ]
}
EOF

rm ${my_backstage}/app-config.yaml

cat <<EOF | tee ${my_backstage}/app-config.yaml
app:
  title: Scaffolded Backstage App
  baseUrl: http://localhost:3000

organization:
  name: My Company

backend:
  # Used for enabling authentication, secret is shared by all backend plugins
  # See https://backstage.io/docs/auth/service-to-service-auth for
  # information on the format
  # auth:
  #   keys:
  #     - secret: ${BACKEND_SECRET}
  baseUrl: http://localhost:7007
  listen:
    port: 7007
    # Uncomment the following host directive to bind to specific interfaces
    # host: 127.0.0.1
  csp:
    connect-src: ["'self'", 'http:', 'https:']
    # Content-Security-Policy directives follow the Helmet format: https://helmetjs.github.io/#reference
    # Default Helmet Content-Security-Policy values can be removed by setting the key to false
  cors:
    origin: http://localhost:3000
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  # This is for local development only, it is not recommended to use this in production
  # The production database configuration is stored in app-config.production.yaml
  database:
    client: better-sqlite3
    connection: ':memory:'
  # workingDirectory: /tmp # Use this to configure a working directory for the scaffolder, defaults to the OS temp-dir

integrations:
  aws:
    profile: default
  github:
    - host: github.com
      # This is a Personal Access Token or PAT from GitHub. You can find out how to generate this token, and more information
      # about setting up the GitHub integration here: https://backstage.io/docs/getting-started/configuration#setting-up-a-github-integration
      token: ${GITHUB_TOKEN}
    ### Example for how to add your GitHub Enterprise instance using the API:
    # - host: ghe.example.net
    #   apiBaseUrl: https://ghe.example.net/api/v3
    #   token: ${GHE_TOKEN}

proxy:
  ### Example for how to add a proxy endpoint for the frontend.
  ### A typical reason to do this is to handle HTTPS and CORS for internal services.
  # '/test':
  #   target: 'https://example.com'
  #   changeOrigin: true

# Reference documentation http://backstage.io/docs/features/techdocs/configuration
# Note: After experimenting with basic setup, use CI/CD to generate docs
# and an external cloud storage when deploying TechDocs for production use-case.
# https://backstage.io/docs/features/techdocs/how-to-guides#how-to-migrate-from-techdocs-basic-to-recommended-deployment-approach
techdocs:
  builder: 'local' # Alternatives - 'external'
  generator:
    runIn: 'docker' # Alternatives - 'local'
  publisher:
    type: 'local' # Alternatives - 'googleGcs' or 'awsS3'. Read documentation for using alternatives.

auth:
  # see https://backstage.io/docs/auth/ to learn about auth providers
  providers: {}

scaffolder:
  # see https://backstage.io/docs/features/software-templates/configuration for software template options

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location]
  locations:
    # Local example data, file locations are relative to the backend process, typically `packages/backend`
    - type: file
      target: ../../examples/entities.yaml

    # Local example template
    - type: file
      target: ../../examples/template/template.yaml
      rules:
        - allow: [Template]

    # Local example organizational data
    - type: file
      target: ../../examples/org.yaml
      rules:
        - allow: [User, Group]

    ## Uncomment these lines to add more example data
    # - type: url
    #   target: https://github.com/backstage/backstage/blob/master/packages/catalog-model/examples/all.yaml

    ## Uncomment these lines to add an example org
    # - type: url
    #   target: https://github.com/backstage/backstage/blob/master/packages/catalog-model/examples/acme-corp.yaml
    #   rules:
    #     - allow: [User, Group]
    # Pull single stack from the profile "myProfile"
    # - type: aws:cloudformation:stack
    #   target: myProfile@arn:aws:cloudformation:ap-southeast-1:123456789000:stack/some-stack/123-345-12-1235-123123
    # Pull single stack from the default profile
    # - type: aws:cloudformation:stack
    #   target: arn:aws:cloudformation:eu-central-1:123456789000:stack/other-stack/532-123-59-593-19481
    # Pull whole region from the "myProfile" profile
    # - type: aws:cloudformation:region
    #   target: myProfile@ap-southeast-1
    # Pull whole region from the default profile
    - type: aws:cloudformation:region
      target: us-east-1
EOF

cd ${my_backstage}
yarn dev
