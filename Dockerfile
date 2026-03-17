# =============================================================================
# Stage 1: builder
# 使用含完整 Go 工具鏈的官方 Alpine 映像編譯二進位檔
# =============================================================================
FROM golang:1.24-alpine AS builder

WORKDIR /app

# 優先複製依賴描述檔，讓 Docker 在程式碼未變動時直接使用快取層
# 若無外部依賴則 go mod download 為 no-op，但保留此結構方便日後擴充
COPY go.mod ./
RUN go mod download

# 複製全部原始碼
COPY . .

# 同時編譯兩個入口點：
#   - issue2mdweb：Web 服務（根目錄 main.go）
#   - issue2md：CLI 工具（cmd/issue2md/main.go）
# CGO_ENABLED=0 產生靜態連結二進位，可直接在無 glibc 的映像中執行
# -ldflags="-s -w" 移除 debug 符號與 DWARF 資訊，縮小二進位體積
RUN CGO_ENABLED=0 GOOS=linux \
    go build -ldflags="-s -w" -o /out/issue2mdweb . && \
    CGO_ENABLED=0 GOOS=linux \
    go build -ldflags="-s -w" -o /out/issue2md ./cmd/issue2md

# =============================================================================
# Stage 2: final
# 使用釘定版本的 Alpine 作為最終執行映像，不含任何原始碼或建置工具
# =============================================================================
FROM alpine:3.21

# 安裝 CA 憑證，讓 Web 服務能對 GitHub API 發起 HTTPS 請求
RUN apk add --no-cache ca-certificates

# 建立非 root 使用者與群組，遵循最小權限原則
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# 從 builder 階段複製編譯好的二進位檔（不含原始碼）
COPY --from=builder /out/issue2mdweb .
COPY --from=builder /out/issue2md .

# 複製 Web 服務所需的靜態資源與模板
# Web 服務以 http.Dir("web/static") 方式掛載，路徑需與 WORKDIR 對應
COPY --from=builder /app/web/templates ./web/templates
COPY --from=builder /app/web/static ./web/static

# 將 /app 目錄擁有權交給非 root 使用者
RUN chown -R appuser:appgroup /app

# 切換至非 root 使用者執行
USER appuser

EXPOSE 8080

# 預設啟動 Web 服務；CLI 工具可透過 docker run --entrypoint ./issue2md 呼叫
ENTRYPOINT ["./issue2mdweb"]
