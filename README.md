# aws-emul-terraform-test

[AWS Emulator](https://docs.aws.amazon.com/emulator/latest/userguide/what-is-service.html)([GitHub](https://github.com/aws/aws-emulator))를 로컬 Docker로 띄우고 Terraform으로 S3 / VPC / IAM / EKS 리소스를 만들어 보는 테스트 프로젝트.

## 구조
```
emulator/Dockerfile        # 공식 문서의 Dockerfile (공식 이미지 없음 → 직접 빌드)
scripts/start-emulator.ps1 # 이미지 빌드 + 127.0.0.1:9297 실행 + health 체크
scripts/tf.ps1             # Terraform을 에뮬레이터 네트워크의 컨테이너에서 실행 (Avast 우회)
scripts/aws.ps1            # AWS CLI를 같은 방식으로 실행 (리소스 조회용)
scripts/kubectl.ps1        # 에뮬레이트된 EKS 클러스터에 kubectl 실행 (토큰/CA 자동)
k8s/nginx-pod.yaml         # EKS API 스모크 테스트용 매니페스트
scripts/env.ps1            # AWS_* 환경변수를 에뮬레이터로 설정 (dot-source, Windows 직접 실행용)
scripts/reset-state.ps1    # 에뮬레이터 재기동 후 tfstate 삭제
env/eks-test1/             # Terraform 환경 #1 (S3 + VPC + IAM + EKS)
```

## 실행 순서 (PowerShell)
이 PC에서는 Avast가 로컬 HTTPS를 가로채므로(아래 트러블슈팅) **Terraform을 컨테이너로 실행**한다.
`scripts/tf.ps1`은 `hashicorp/terraform` 컨테이너를 에뮬레이터 컨테이너와 같은 네트워크(`--network container:aws-emulator`)에서 띄운다.
```powershell
# 1) Docker Desktop 실행 후
.\scripts\start-emulator.ps1            # 기본: -a off, --telemetry off

# 2) Terraform (컨테이너 실행, 기본 환경 eks-test1)
.\scripts\tf.ps1 init
.\scripts\tf.ps1 apply -auto-approve
.\scripts\tf.ps1 output
.\scripts\tf.ps1 destroy -auto-approve
.\scripts\tf.ps1 -Env other-env plan    # 다른 env/<이름> 대상
```
- 컨테이너 안에서 쓰는 provider는 `.terraform-linux/`에 받는다(Windows 쪽 `.terraform/`과 분리).
- Avast HTTPS 스캔을 끈 PC라면 `. .\scripts\env.ps1` 후 Windows의 `terraform` / `aws`를 직접 써도 된다.
- 에뮬레이터는 모든 리소스를 메모리에 둔다. 컨테이너를 재시작했다면 `.\scripts\reset-state.ps1`로 tfstate를 지울 것.

## 리소스 조회 (콘솔 없음)
에뮬레이터에는 GUI/콘솔이 없다. CLI로 조회한다.
```powershell
.\scripts\tf.ps1 state list                     # Terraform이 관리하는 리소스
.\scripts\tf.ps1 state show aws_eks_cluster.this[0]
.\scripts\aws.ps1 s3 ls
.\scripts\aws.ps1 ec2 describe-vpcs --output table
.\scripts\aws.ps1 eks describe-cluster --name eks-test1
.\scripts\aws.ps1 resourcegroupstaggingapi get-resources --output table   # 태그 붙은 전체 리소스
```

## EKS 접근 (kubectl)
```powershell
.\scripts\kubectl.ps1 get nodes
.\scripts\kubectl.ps1 api-resources
.\scripts\kubectl.ps1 create --validate=false -f k8s/nginx-pod.yaml
.\scripts\kubectl.ps1 get pod nginx -n nginx-test -o "jsonpath={.status.phase} / {.status.message}"
```
`kubectl.ps1`이 `describe-cluster`로 endpoint/CA를, `aws eks get-token`으로 토큰을 받아 kubectl 컨테이너에 넘긴다.

에뮬레이트된 K8s API 실측 지원 범위:
- 제공 리소스: Namespace, Pod, ConfigMap, ServiceAccount, Node, Role/RoleBinding/ClusterRole/ClusterRoleBinding, SelfSubjectReview
- **없음**: Deployment(apps/v1), Service, Ingress 등
- **컨테이너를 실행하지 않음**: Pod는 저장만 되고 `Failed` / `This emulator does not run containers`
- PATCH / DELETE 거부 → `kubectl apply` 재적용·`kubectl delete` 불가 (`create`만 가능)
- `/openapi/v2` 없음 → `--validate=false` 필요

→ **nginx를 실제로 띄워 보는 테스트는 에뮬레이터로 불가능.** EKS 리소스를 Terraform으로 만드는 테스트까지가 범위다.

## 실측 결과 (2026-11-17, emulator LTS latest, Terraform 1.13.4, hashicorp/aws 6.22.1)
| 항목 | 결과 |
|---|---|
| `aws_s3_bucket` / versioning / object | 성공 |
| VPC / Subnet / IGW / RouteTable / SG | 성공 |
| IAM role + policy attachment | 성공 |
| `aws_eks_cluster` | 성공, endpoint `https://127.0.0.1:<임의 포트>` (에뮬레이터 컨테이너 내부 포트) |
| `aws_eks_node_group` | 성공, status `ACTIVE`, 노드 1개 조회됨 |
| hashicorp/aws **6.23.0** + `aws_s3_bucket` | **실패** (#56 재현): `S3 Control: ListTagsForResource ... lookup 000000000000.127.0.0.1: no such host` |
| K8s API (`aws eks get-token` 토큰) | `/version` 200 (`v1.33`, platform `emulator`), namespace 생성 201, pod 생성 201 → phase `Failed` |
| K8s API 그룹 | core `v1`, `authentication.k8s.io/v1`, `rbac.authorization.k8s.io/v1` 만 제공 — **`apps/v1` 없음(Deployment 불가)** |
| `/openapi/v2` | 404 → `kubectl apply`는 `--validate=false` 필요 |
| 토큰 없는 요청 | 401 |

## Terraform 연결 방식
- 전용 래퍼(tflocal 등) 없음. Terraform AWS provider가 표준 환경변수를 읽는다:
  `AWS_ENDPOINT_URL=https://127.0.0.1:9297`, `AWS_CA_BUNDLE=~\.aws\emulator\9297\ca.pem`,
  `AWS_SHARED_CREDENTIALS_FILE`, `AWS_CONFIG_FILE`, `AWS_DISABLE_HOST_PREFIX_INJECTION=true` 등 (`scripts/env.ps1`).
- `s3_use_path_style = true` 필수, 호스트는 `localhost`가 아닌 `127.0.0.1`.
- CA 인증서는 에뮬레이터 기동마다 바뀌지만 경로를 가리키므로 그대로 동작.

## 버전 제약 (S3)
**Terraform CLI 버전이 아니라 `hashicorp/aws` provider 버전 문제다.**

| 제약 | 원인 | 근거 |
|---|---|---|
| `hashicorp/aws < 6.23.0` (여기선 `~> 6.22.0`) | 6.23.0부터 `aws_s3_bucket` 태그를 S3 Control API로 처리 → S3 Control은 호스트에 계정ID 접두사가 붙어 에뮬레이터에 도달 불가 | [#56](https://github.com/aws/aws-emulator/issues/56) (open, v1.0.471에서도 재현) |
| 에뮬레이터 `-a off` | 인증 ON일 때 `aws_s3_bucket` 생성 마지막 익명 HeadBucket이 403 | [#353](https://github.com/aws/aws-emulator/issues/353) (open) |

그 외: S3 Control 기반 리소스(`aws_s3_account_public_access_block`, access point 등)는 사용 불가.

## EKS 지원 수준
- **EKS API(컨트롤플레인)는 지원**: CreateCluster / DescribeCluster / NodeGroup / AccessEntry / Addon 등 (`services/service-com-amazonaws-eks-*`). 일부 stub 존재(ListFargateProfiles 등).
- 클러스터마다 **에뮬레이트된 Kubernetes API**를 제공하지만 실제 k8s가 아니다(파드가 실제로 실행되지 않음). 알려진 문제:
  - `/openapi/v2,v3` 미제공 → `kubectl apply`는 `--validate=false` 필요, helm / Terraform kubernetes provider 실패 가능.
  - endpoint가 `*.eks.amazonaws.com`으로 발급되어 접근 안 되는 이슈 보고됨.
- 결론: `aws_eks_cluster`, `aws_eks_node_group` 생성 테스트 용도로만 사용. 클러스터 내부 워크로드 배포는 기대하지 말 것.
- 노드 인스턴스 타입은 T 계열 금지 ([#422](https://github.com/aws/aws-emulator/issues/422)) → `m5.large`.

## 기타 제약
- 단일 리전/계정 (`000000000000`), IAM 정책 평가 안 함 → 보안 테스트 불가.
- 미구현 API는 HTTP 501 `NotImplemented`.

## 트러블슈팅
### Windows에서 `Plugin did not respond` / `CERTIFICATE_VERIFY_FAILED`
Avast Web Shield의 HTTPS 스캔이 로컬 TLS를 가로챈다. `127.0.0.1:9297`에서 받은 인증서의 issuer가
`Avast Web/Mail Shield Self-signed Root`로 바뀌어 있어 에뮬레이터 `ca.pem`으로 검증이 실패하고,
Terraform 코어 ↔ provider 플러그인 간 mTLS도 깨진다. 프로그램 예외 추가로는 해결되지 않았다.
- 해결 1: `scripts/tf.ps1`로 컨테이너에서 실행 (현재 방식, Avast 설정 변경 불필요)
- 해결 2: Avast → 설정 → 보호 → 핵심 보호 → Web Shield → "HTTPS 스캔 활성화" 해제

### Windows `curl.exe`로 health 체크 실패
`curl.exe`(schannel)는 에뮬레이터 자체서명 인증서를 `the certificate chain is incomplete`로 거부한다. 컨테이너 안의 curl을 쓰거나 `docker logs aws-emulator`로 기동을 확인한다.

### EKS endpoint 접근
endpoint 포트는 에뮬레이터 컨테이너 안에만 열린다. `--network container:aws-emulator`로 띄운 컨테이너에서 `aws eks get-token`으로 토큰을 받아 호출한다.
