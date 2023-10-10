# The problem

One of our clients is running Kubernetes on AWS (EKS + Terraform). At the moment, they store secrets like database passwords in a configuration file of the application, which is stored along with the code in Github. The resulting application pod is getting an ENV variable with the name of the environment, like staging or production, and the configuration file loads the relevant secrets for that environment.

We would like to help them improve the way they work with this kind of sensitive data.

Please also note that they have a small team and their capacity for self-hosted solutions is limited.

Provide one or two options for how would you propose them to change how they save and manage their secrets.

# The solution

I assume that currently the configuration files are baked into the Docker image in plain text during the application build. In that case, I suggest the following changes:

##### Step 0

Store the configuration file into [kubernetes secrets](https://kubernetes.io/docs/concepts/configuration/secret) rather than baking it into the base image as a more secure and flexible approach. We can store the entire file as a whole or split it into key-value pairs depending on the type of configuration file. The only issue with kubernetes secrets is that they are accessible at the namespace level. Therefore, it's a good practice to limit the number of applications within a namespace for better security. However, questions about organizing applications into namespaces and the levels of isolation go beyond the scope of the current request.

Pros of storing the config as a single file:
- You won't need to change the application code, only the file path
- [Kubernetes will automatically update](https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-files-from-a-pod) the file when the secret changes, and the application can monitor these changes and perform configuration updates during runtime

Cons of storing the config as a single file:
- Before loading into the secret, the config file must be encoded in base64. Therefore, making changes to the config will require decoding it first and then encoding it again, adding complexity when making updates

Pros of splitting the configuration into key-value pairs:
- You can load them into environment variables to adhere to the [12-factor app](https://12factor.net/) best practices
- Most frameworks can read configuration from environment variables, minimizing code changes

Cons of splitting the configuration into key-value pairs:
- When using environment variables, changing the secret will require restarting the application containers to apply the new configuration
- If using files instead of environment variables, the downside compared to a single config file is that you'll have as many files to track as there are parameters, and you'll likely need to make changes to the application code to support this

To start with, the cluster administrator can manually create and update secrets for apps.

In the future, it's a common practice to separate regular configuration from secrets. You can store regular configuration in [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) or environment variables, which provides more flexibility and better management. ConfigMaps are suitable for non-sensitive configuration data allow you to use templating, while environment variables are convenient for configuring applications and adhere to 12-factor app principles.

##### Step 1

Configure gitops way of storing such secrets. You can choose and adopt one of this ways for storing k8s secrets in encrypted form in your git repo according to your setup. The only downside is that updating secrets will require more effort.

- You can encrypt your secrets with an asymmetric public key and store them in Git. Then, your CI/CD pipeline can decrypt them using the private key and apply them to the cluster. You can write a small script to accomplish this or adopt one of the available tools for better security and user access management: [helm-secrets](https://github.com/jkroepke/helm-secrets), [sops](https://github.com/getsops/sops), [age](https://github.com/FiloSottile/age), [openpgp](https://www.openpgp.org/), [ansible vault](https://docs.ansible.com/ansible/2.8/user_guide/vault.html)

- Instead of decrypting in the CI/CD pipeline, you can use a dedicated kubernetes controller for this purpose: [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)

##### Step 2

In the future, you can consider integrating one of the following significant tools, either into your kubernetes cluster or into your applications directly:

- [Hashicorp Vault](https://www.vaultproject.io/)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
- [Google Cloud Secret Manager](https://cloud.google.com/secret-manager)
- [Azure Key Vault](https://azure.microsoft.com/en-us/products/key-vault)
- [Infisical](https://infisical.com/)
- [1password.com](https://1password.com/product/secrets/)
- [Conjur](https://www.conjur.org/)
