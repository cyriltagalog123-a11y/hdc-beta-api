import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_community_provider.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<HDCAuthProvider>();
      if (auth.authenticated && !auth.guestMode) {
        context.read<HdcCommunityProvider>().refreshSuggestions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final provider = context.watch<HdcCommunityProvider>();
    final registered = auth.authenticated && !auth.guestMode && auth.identity != null;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(title: const Text('Suggestions')),
      body: RefreshIndicator(
        onRefresh: registered
            ? provider.refreshSuggestions
            : () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            HDCFlowHero(
              eyebrow: 'HELP SHAPE HDC',
              title: 'Have an idea? Send it directly to HDC.',
              description:
                  'Suggestions are a standalone HDC channel. Signed-in members can submit an idea, track its status, and read the owner response. Your submission is not made public just because you sent it.',
              icon: Icons.lightbulb_outline_rounded,
              action: registered
                  ? FilledButton.icon(
                      onPressed: () => _openSuggestionDialog(context, provider),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('New Suggestion'),
                    )
                  : null,
              tags: const [
                HDCFlowTag(
                  label: 'Tracked privately',
                  icon: Icons.lock_outline_rounded,
                ),
                HDCFlowTag(
                  label: 'Owner-reviewed',
                  icon: Icons.verified_user_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!registered)
              const HDCSectionCard(
                title: 'Suggestion page is visible in Guest mode',
                subtitle: 'Sign in to submit and track your own ideas.',
                child: Text(
                  'HDC keeps suggestions tied to verified member accounts so responses, implementation credit, and abuse controls remain reliable. Exit Guest mode and sign in when you are ready to submit.',
                ),
              )
            else if (provider.errorMessage != null && provider.suggestions.isEmpty)
              HDCEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Suggestions are temporarily unavailable',
                description: provider.errorMessage!,
                actions: [
                  OutlinedButton.icon(
                    onPressed: provider.refreshSuggestions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              )
            else if (provider.suggestions.isEmpty)
              const HDCEmptyState(
                icon: Icons.forum_outlined,
                title: 'You have not submitted a suggestion yet',
                description:
                    'Send a concrete feature, usability, marketplace, service workflow, safety, Knowledge Base, or other improvement idea. Only you and the Owner review workspace can see the submitted record.',
              )
            else ...[
              Text(
                'Your suggestions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Status changes and owner responses appear here.',
                style: TextStyle(color: HDCColors.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final suggestion in provider.suggestions) ...[
                HDCSectionCard(
                  title: suggestion.title,
                  subtitle:
                      '${suggestion.publicSuggestionId} • ${suggestion.category.replaceAll('_', ' ')}',
                  trailing: Chip(label: Text(suggestion.status.toUpperCase())),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(suggestion.body),
                      if (suggestion.staffResponse.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: HDCColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: HDCColors.primary.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Owner response',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 5),
                              Text(suggestion.staffResponse),
                            ],
                          ),
                        ),
                      ],
                      if (suggestion.publicAttributionConsent) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Public recognition consent is enabled if HDC later chooses to recognize this contribution. Recognition is never automatic.',
                          style: TextStyle(color: HDCColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (provider.isLoading && registered) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSuggestionDialog(
    BuildContext context,
    HdcCommunityProvider provider,
  ) async {
    var category = 'feature';
    var consent = false;
    final title = TextEditingController();
    final body = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New HDC Suggestion'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const {
                      'feature': 'Feature',
                      'usability': 'Usability',
                      'marketplace': 'Marketplace',
                      'service_workflow': 'Service workflow',
                      'safety': 'Safety',
                      'knowledge_base': 'Knowledge Base',
                      'other': 'Other',
                    }
                        .entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => category = value ?? 'feature'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: body,
                    maxLength: 5000,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Suggestion',
                      hintText:
                          'Describe the problem, your proposed improvement, and why it would help.',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: (value) =>
                        setState(() => consent = value == true),
                    title: const Text(
                      'Allow public credit if HDC recognizes this suggestion',
                    ),
                    subtitle: const Text(
                      'Consent does not guarantee publication or implementation.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) {
      title.dispose();
      body.dispose();
      return;
    }

    try {
      await provider.submitSuggestion(
        category: category,
        title: title.text,
        body: body.text,
        publicAttributionConsent: consent,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suggestion submitted to HDC.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      title.dispose();
      body.dispose();
    }
  }
}
