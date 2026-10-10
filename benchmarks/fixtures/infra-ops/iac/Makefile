# Day-to-day Terraform for the prod root. CI runs plan; applies go through `make apply`.
ENV ?= prod

plan:
	terraform -chdir=envs/$(ENV) plan -input=false -out=tfplan

apply:
	terraform -chdir=envs/$(ENV) apply -input=false tfplan
