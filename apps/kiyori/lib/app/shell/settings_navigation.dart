import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/browser/presentation/browser_settings_page.dart';
import '../../features/browser/presentation/browser_home_page.dart';
import '../../features/browser/presentation/browser_text_size_page.dart';
import '../../features/browser/presentation/browser_password_page.dart';
import '../../features/browser/presentation/browser_script_permissions_page.dart';
import '../../features/files/presentation/file_settings_page.dart';
import '../../features/downloads/presentation/download_settings_page.dart';
import '../../features/video/presentation/player_settings_page.dart';
import '../../features/video/presentation/player_experience_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/more_settings_page.dart';
import '../../features/settings/presentation/storage_paths_page.dart';
import '../../features/settings/presentation/artifact_storage_page.dart';
import '../../features/settings/presentation/network_proxy_page.dart';
import '../../features/settings/presentation/legal_document.dart';
import '../../features/settings/presentation/legal_document_page.dart';
import '../../features/settings/presentation/permissions_page.dart';
import '../../features/settings/presentation/open_source_page.dart';
import '../../features/settings/presentation/backup_settings_page.dart';
import '../../features/settings/presentation/appearance/appearance_settings_page.dart';
import '../../features/settings/presentation/appearance/appearance_menu_page.dart';
import '../../features/settings/presentation/data_settings_page.dart';
import '../../features/assistant/presentation/assistant_settings_page.dart';
import '../../features/assistant/presentation/avatar_settings_page.dart';
import '../../features/assistant/presentation/prompts/model_prompts_page.dart';
import '../../features/assistant/presentation/prompts/tag_market_page.dart';
import '../../features/assistant/presentation/prompts/persona_generation_page.dart';
import '../../features/assistant/presentation/history/chat_history_page.dart';
import '../../features/assistant/presentation/context/context_summary_page.dart';
import '../../features/assistant/presentation/models/function_models_page.dart';
import '../../features/assistant/presentation/models/model_api_page.dart';
import '../../features/assistant/presentation/permissions/tool_permissions_page.dart';
import '../../features/assistant/presentation/profile/user_profile_page.dart';
import '../../features/assistant/presentation/server/lan_automation_page.dart';
import '../../features/assistant/presentation/replies/reply_preferences_page.dart';
import '../../features/assistant/presentation/replies/custom_emoji_page.dart';
import '../../features/assistant/presentation/replies/emoji_presentation.dart';
import '../../features/assistant/presentation/usage/usage_page.dart';
import '../../features/speech/presentation/stt_settings_page.dart';
import '../../features/speech/presentation/tts_settings_page.dart';
import '../../features/speech/presentation/tts_tool_page.dart';
import '../../features/speech/presentation/wakeup_settings_page.dart';
import '../../features/accounts/presentation/account_settings_page.dart';
import '../../features/settings/presentation/appearance/language_settings_page.dart';
import '../../features/settings/presentation/appearance/global_display_page.dart';
import '../../features/settings/presentation/appearance/layout_adjustment_page.dart';
import '../../features/toolbox/presentation/toolbox_settings_page.dart';
import '../../features/documents/presentation/document_settings_page.dart';
import '../../features/music/presentation/music_settings_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/browser/presentation/adblock_settings_page.dart';

/// 详情路由的装配层；只借用现有 Navigator，不持有目的地或业务状态。
class SettingsNavigation {
  SettingsNavigation(this.navigator);
  final NavigatorState navigator;

  Widget buildSettingsPage() => SettingsPage(
    onOpenAssistant: () => openPage(
      AssistantSettingsPage(
        onOpen: (section) {
          if (section == AssistantSettingsSection.artifacts) {
            openPage(const ArtifactStoragePage());
          } else if (section == AssistantSettingsSection.context) {
            openPage(const ContextSummaryPage());
          } else if (section == AssistantSettingsSection.functions) {
            openPage(
              FunctionModelsPage(
                onManage: () => openPage(const ModelApiPage()),
              ),
            );
          } else if (section == AssistantSettingsSection.models) {
            openPage(const ModelApiPage());
          } else if (section == AssistantSettingsSection.roles) {
            openPage(
              ModelPromptsPage(
                onOpenTagMarket: () => openPage(const TagMarketPage()),
                onOpenPersona: () => openPage(const PersonaGenerationPage()),
              ),
            );
          } else if (section == AssistantSettingsSection.avatar) {
            openPage(const AvatarSettingsPage());
          } else if (section == AssistantSettingsSection.permissions) {
            openPage(const ToolPermissionsPage());
          } else if (section == AssistantSettingsSection.profile) {
            openPage(const UserProfilePage());
          } else if (section == AssistantSettingsSection.server) {
            openPage(const LanAutomationPage());
          } else if (section == AssistantSettingsSection.usage) {
            openPage(const UsagePage());
          } else if (section == AssistantSettingsSection.stt) {
            openPage(const SttSettingsPage());
          } else if (section == AssistantSettingsSection.tts) {
            openPage(
              TtsSettingsPage(onTest: () => openPage(const TtsToolPage())),
            );
          } else if (section == AssistantSettingsSection.wakeup) {
            openPage(const WakeupSettingsPage());
          } else if (section == AssistantSettingsSection.replies) {
            openPage(
              ReplyPreferencesPage(
                onCustomEmoji: () => openPage(
                  CustomEmojiPage(snapshot: EmojiLibraryPresentation.bundled),
                ),
              ),
            );
          }
        },
      ),
    ),
    onOpenAccount: () => openPage(const AccountSettingsPage()),
    onOpenAppearance: () => openPage(
      AppearanceMenuPage(
        onOpen: (section) {
          if (section == AppearanceSection.theme) {
            openPage(const AppearanceSettingsPage());
          } else if (section == AppearanceSection.language) {
            openPage(const LanguageSettingsPage());
          } else if (section == AppearanceSection.display) {
            openPage(const GlobalDisplayPage());
          } else if (section == AppearanceSection.layout) {
            openPage(const LayoutAdjustmentPage());
          }
        },
      ),
    ),
    onOpenBackup: () => openPage(
      DataSettingsPage(
        onBackup: () => openPage(const BackupSettingsPage()),
        onHistory: () => openPage(const ChatHistoryPage()),
      ),
    ),
    onOpenMore: () => openPage(MoreSettingsPage(onOpen: openMoreSettings)),
    onOpenAdblock: () => openAdblock(AdblockSection.overview),
    onOpenMusic: () => unawaited(
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const MusicSettingsPage()),
      ),
    ),
    onOpenToolbox: openToolboxSettings,
    onOpenPlayer: () => unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => PlayerSettingsPage(
            onOpenDetail: (section) => unawaited(
              navigator.push<void>(
                MaterialPageRoute(
                  builder: (_) => PlayerExperiencePage(section: section),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    onOpenFiles: openFileSettings,
    onOpenBrowser: () => openBrowserSettings('browser.settings'),
    onOpenDownloads: () => unawaited(
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const DownloadSettingsPage()),
      ),
    ),
  );

  void openBrowserSettings(String route) {
    final Widget page;
    switch (route) {
      case 'browser.settings':
        page = BrowserSettingsPage(onOpen: openBrowserSettings);
      case 'browser.home':
        page = const BrowserHomePage();
      case 'browser.text-size':
        page = const BrowserTextSizePage();
      case 'browser.passwords':
        page = const BrowserPasswordPage();
      case 'browser.permissions':
        page = const BrowserScriptPermissionsPage();
      default:
        return;
    }
    unawaited(navigator.push<void>(MaterialPageRoute(builder: (_) => page)));
  }

  void openFileSettings() {
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const FileSettingsPage()),
      ),
    );
  }

  void openSpeechTool() => openPage(const TtsToolPage());

  void openPage(Widget page) {
    unawaited(navigator.push<void>(MaterialPageRoute(builder: (_) => page)));
  }

  void openMoreSettings(MoreSettingsSection section) {
    switch (section) {
      case MoreSettingsSection.storage:
        openPage(StoragePathsPage(onOpen: openStorageSettings));
      case MoreSettingsSection.network:
        openNetworkSettings(NetworkProxySection.overview);
      case MoreSettingsSection.agreement:
        openPage(const LegalDocumentPage(document: LegalDocument.agreement));
      case MoreSettingsSection.privacy:
        openPage(const LegalDocumentPage(document: LegalDocument.privacy));
      case MoreSettingsSection.permissions:
        openPage(const PermissionsPage());
      case MoreSettingsSection.licenses:
        openPage(const OpenSourcePage());
      case MoreSettingsSection.onboarding:
        unawaited(
          showGeneralDialog<void>(
            context: navigator.context,
            pageBuilder: (_, _, _) => const OnboardingPage(reviewing: true),
          ),
        );
    }
  }

  void openNetworkSettings(NetworkProxySection section) {
    openPage(NetworkProxyPage(section: section, onOpen: openNetworkSettings));
  }

  void openStorageSettings(StorageSettingsSection section) {
    switch (section) {
      case StorageSettingsSection.files:
        openFileSettings();
      case StorageSettingsSection.downloads:
        openPage(const DownloadSettingsPage());
      case StorageSettingsSection.player:
        openPage(
          PlayerSettingsPage(
            onOpenDetail: (section) =>
                openPage(PlayerExperiencePage(section: section)),
          ),
        );
      case StorageSettingsSection.artifacts:
        openPage(const ArtifactStoragePage());
      case StorageSettingsSection.backup:
        openPage(const BackupSettingsPage());
    }
  }

  void openToolboxSettings() {
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => ToolboxSettingsPage(
            onOpenDocuments: () => unawaited(
              navigator.push<void>(
                MaterialPageRoute(builder: (_) => const DocumentSettingsPage()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void openAdblock(AdblockSection section) {
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) =>
              AdblockSettingsPage(section: section, onOpen: openAdblock),
        ),
      ),
    );
  }
}
