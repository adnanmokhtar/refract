.PHONY: test test-api test-web test-svc test-ledger test-jvm

test: test-api test-web test-svc test-ledger test-jvm

test-api:
	npm test --workspace api
	npm run test:e2e --workspace api

test-web:
	npm test --workspace web

test-svc:
	cd svc && python -m pytest -q

test-ledger:
	cd ledger && go test ./...

test-jvm:
	mvn -B -f jvm/pom.xml test
