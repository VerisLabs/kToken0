# kToken Protocol Deployment Makefile
# Usage: make deploy-hub, make deploy-spoke CHAIN=polygon
-include .env
export

.PHONY: help deploy-hub deploy-spoke verify clean clean-all format-output test build

# Default target
help:
	@echo "kToken Protocol Deployment Commands"
	@echo "==================================="
	@echo "make deploy-hub         - Deploy hub (mainnet: kToken0 + kOFTAdapter)"
	@echo "make deploy-spoke CHAIN=<chain> - Deploy spoke (kToken0 + kOFT)"
	@echo "make verify             - Verify deployment configuration"
	@echo "make clean              - Clean deployment files"
	@echo "make test               - Run tests"
	@echo "make build              - Build contracts"
	@echo ""
	@echo "Available chains for deploy-spoke:"
	@echo "  sepolia, polygon, arbitrum, optimism, optimism-sepolia, bsc, avalanche, localhost"

# Hub deployment (mainnet only)
deploy-hub:
	@echo "🔴 Deploying HUB to MAINNET (kToken0 + kOFTAdapter)..."
	@$(MAKE) check-rpc RPC_VAR=RPC_MAINNET
	forge script script/DeployHub.s.sol --rpc-url ${RPC_MAINNET} --broadcast --account keyDeployer --sender ${DEPLOYER_ADDRESS} --slow --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

# Spoke deployment (all other chains)
deploy-spoke:
	@echo "🔗 Deploying SPOKE to $(CHAIN) (kToken0 + kOFT)..."
	@if [ -z "$(CHAIN)" ]; then \
		echo "❌ Error: CHAIN variable not set"; \
		echo "Usage: make deploy-spoke CHAIN=polygon"; \
		exit 1; \
	fi
	@$(MAKE) check-rpc CHAIN=$(CHAIN)
	@$(MAKE) get-rpc-args CHAIN=$(CHAIN)
	forge script script/DeploySpoke.s.sol $(RPC_ARGS) --broadcast --account keyDeployer --sender ${DEPLOYER_ADDRESS}

# Check RPC URL is set
check-rpc:
	@if [ -z "$($(RPC_VAR))" ]; then \
		echo "❌ Error: $(RPC_VAR) environment variable not set"; \
		exit 1; \
	fi
	@echo "✅ Using RPC: $($(RPC_VAR))"

# Get RPC args for specific chain
get-rpc-args:
	@case "$(CHAIN)" in \
		sepolia) \
			RPC_ARGS="--rpc-url $(RPC_SEPOLIA)"; \
			;; \
		polygon) \
			RPC_ARGS="--rpc-url $(RPC_POLYGON) --verify --polygonscan-api-key $(POLYGONSCAN_API_KEY)"; \
			;; \
		arbitrum) \
			RPC_ARGS="--rpc-url $(RPC_ARBITRUM) --verify --arbiscan-api-key $(ARBISCAN_API_KEY)"; \
			;; \
		optimism) \
			RPC_ARGS="--rpc-url $(RPC_OPTIMISM) --verify --etherscan-api-key $(ETHERSCAN_API_KEY)"; \
			;; \
		optimism-sepolia) \
			RPC_ARGS="--rpc-url $(RPC_OPTIMISM_SEPOLIA)"; \
			;; \
		bsc) \
			RPC_ARGS="--rpc-url $(RPC_BSC) --verify --bscscan-api-key $(BSCSCAN_API_KEY)"; \
			;; \
		avalanche) \
			RPC_ARGS="--rpc-url $(RPC_AVALANCHE) --verify --snowtrace-api-key $(SNOWTRACE_API_KEY)"; \
			;; \
		localhost) \
			RPC_ARGS="--rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --slow"; \
			;; \
		*) \
			echo "❌ Error: Unknown chain $(CHAIN)"; \
			echo "Available chains: sepolia, polygon, arbitrum, optimism, optimism-sepolia, bsc, avalanche, localhost"; \
			exit 1; \
			;; \
	esac

# Convenience targets for specific chains
deploy-sepolia:
	@$(MAKE) deploy-spoke CHAIN=sepolia

deploy-polygon:
	@$(MAKE) deploy-spoke CHAIN=polygon

deploy-arbitrum:
	@$(MAKE) deploy-spoke CHAIN=arbitrum

deploy-optimism:
	@$(MAKE) deploy-spoke CHAIN=optimism

deploy-optimism-sepolia:
	@$(MAKE) deploy-spoke CHAIN=optimism-sepolia

deploy-bsc:
	@$(MAKE) deploy-spoke CHAIN=bsc

deploy-avalanche:
	@$(MAKE) deploy-spoke CHAIN=avalanche

deploy-localhost:
	@$(MAKE) deploy-spoke CHAIN=localhost

# Verification
verify:
	@echo "🔍 Verifying deployment configuration..."
	@if [ ! -f "deployments/config/mainnet.json" ]; then \
		echo "❌ Mainnet config not found"; \
		exit 1; \
	fi
	@echo "✅ Configuration files exist"
	@echo "📄 Check deployments/config/ for network settings"
	@echo "📄 Check deployments/output/ for deployed addresses"

# Development helpers
test:
	@echo "🧪 Running tests..."
	forge test

build:
	@echo "🔨 Building contracts..."
	forge build

format-output:
	@echo "📝 Formatting JSON output files..."
	@for file in deployments/output/*/*.json; do \
		if [ -f "$$file" ]; then \
			echo "Formatting $$file"; \
			jq . "$$file" > "$$file.tmp" && mv "$$file.tmp" "$$file"; \
		fi; \
	done
	@echo "✅ JSON files formatted!"

# Cleanup
clean:
	@echo "🧹 Cleaning deployment files..."
	rm -rf deployments/output/localhost/
	@echo "✅ Localhost deployment files cleaned"

clean-all:
	@echo "🧹 Cleaning ALL deployment files..."
	rm -rf deployments/output/*/
	@echo "✅ All deployment files cleaned"

# Documentation
docs:
	@echo "📚 Generating documentation..."
	forge doc --serve --port 4000