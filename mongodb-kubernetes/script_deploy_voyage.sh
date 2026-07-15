### Source: https://docs.aws.amazon.com/eks/latest/userguide/device-management-nvidia.html

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia

helm repo update

helm search repo nvidia/nvidia-dra

helm install nvidia-dra-driver-gpu nvidia/nvidia-dra-driver-gpu \
    --create-namespace \
    --namespace nvidia-dra-driver-gpu \
    --set resources.computeDomains.enabled=false \
    --set 'gpuResourcesEnabledOverride=true'

kubectl get deviceclass

kubectl apply -f - <<EOF
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: single-gpu
spec:
  spec:
    devices:
      requests:
        - name: gpu
          exactly:
            deviceClassName: gpu.nvidia.com
            count: 1
EOF
