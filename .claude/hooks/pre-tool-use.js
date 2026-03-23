module.exports = async function ({ tool, input }) {
    // 防止意外洩露機密
    if (tool === "Read" && input.file_path) {
        if (input.file_path.match(/\.(env|pem|key)$/)) {
            return {
                decision: "ask",
                reason: "This file may contain secrets. Confirm you want to read it."
            };
        }
    }

    return { decision: "allow" };
};