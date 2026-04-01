enum LlmModel {
  // 注意：apiValue 是“路由标识”，后端会映射到真实 OpenAI model id（以服务器配置为准）
  chatgpt52('chatgpt-5.2', 'GPT-5.2'),
  chatgpt54('chatgpt-5.4', 'GPT-5.4'),
  deepseek('deepseek', 'DeepSeek');

  const LlmModel(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// 可走 OpenAI 路线（含联网搜索、图片多模态）
  bool get isOpenAiFamily => this != LlmModel.deepseek;

  static LlmModel fromApi(String v) {
    switch (v) {
      case 'chatgpt-5.2':
      case 'chatgpt':
        return LlmModel.chatgpt52;
      case 'chatgpt-5.4':
        return LlmModel.chatgpt54;
      case 'deepseek':
        return LlmModel.deepseek;
      default:
        return LlmModel.chatgpt52;
    }
  }
}
