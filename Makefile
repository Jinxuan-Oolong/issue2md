# =============================================================================
# issue2md - Makefile
# =============================================================================

# --- 變數定義 -----------------------------------------------------------------
MODULE      := github.com/Jinxuan-Oolong/my-issue2md-project
BIN_CLI     := issue2md
BIN_WEB     := issue2mdweb
IMAGE_TAG   := issue2md:latest
GO          := go
GOFLAGS     := -ldflags="-s -w"

# --- 虛擬目標宣告 -------------------------------------------------------------
.PHONY: all build test lint docker-build clean

# --- 預設目標 -----------------------------------------------------------------
all: build

# --- build：編譯 CLI 與 Web 兩個二進位檔 -------------------------------------
build:
	$(GO) build $(GOFLAGS) -o $(BIN_CLI) ./cmd/issue2md
	$(GO) build $(GOFLAGS) -o $(BIN_WEB) .

# --- test：執行全部單元測試 ---------------------------------------------------
test:
	$(GO) test -v -race ./...

# --- lint：執行 golangci-lint 靜態檢查 ----------------------------------------
lint:
	golangci-lint run ./...

# --- docker-build：使用 Dockerfile 建構容器映像 --------------------------------
docker-build:
	docker build -t $(IMAGE_TAG) .

# --- clean：清除所有建置產物 --------------------------------------------------
clean:
	rm -f $(BIN_CLI) $(BIN_WEB)
