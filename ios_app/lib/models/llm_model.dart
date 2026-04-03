enum LlmModel {
  // 注意：apiValue 是“路由标识”，后端会映射到真实 provider model id（以服务器配置为准）
  chatgpt52('chatgpt-5.2', 'GPT-5.2'),
  chatgpt54('chatgpt-5.4', 'GPT-5.4'),
  geminiFlash('gemini-flash', 'Gemini Flash'),
  geminiPro('gemini-pro', 'Gemini Pro'),
  deepseek('deepseek', 'DeepSeek 对话');

  const LlmModel(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// 支持服务端图片多模态（与后端 supports_vision_route 对齐）
  bool get supportsVision => this != LlmModel.deepseek;

  static LlmModel fromApi(String v) {
    switch (v) {
      case 'chatgpt-5.2':
      case 'chatgpt':
        return LlmModel.chatgpt52;
      case 'chatgpt-5.4':
        return LlmModel.chatgpt54;
      case 'gemini-flash':
        return LlmModel.geminiFlash;
      case 'gemini-pro':
        return LlmModel.geminiPro;
      case 'deepseek':
        return LlmModel.deepseek;
      default:
        return LlmModel.chatgpt52;
    }
  }
}
