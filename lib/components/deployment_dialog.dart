import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/services/deployment_service.dart';
import 'package:flutter/material.dart';

class DeploymentDialog extends StatefulWidget {
  final ClientConfig client;
  final String mode;

  const DeploymentDialog({super.key, required this.client, required this.mode});

  @override
  State<DeploymentDialog> createState() => _DeploymentDialogState();
}

class _DeploymentDialogState extends State<DeploymentDialog> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final DeploymentService _deploymentService = DeploymentService();
  bool _isDeploying = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDeploy();
  }

  Future<void> _startDeploy() async {
    try {
      final stream = await _deploymentService.deploy(
        widget.mode,
        widget.client,
      );
      stream.listen(
        (line) {
          if (mounted) {
            setState(() {
              _logs.add(line);
            });
            _scrollToBottom();
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = e.toString();
              _isDeploying = false;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isDeploying = false;
              _logs.add('--- Deployment Finished ---');
            });
            _scrollToBottom();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isDeploying = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E), // Match terminal background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            widget.mode == 'initial' ? Icons.rocket_launch : Icons.sync,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Deploying: ${widget.client.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 500,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError =
                        log.contains('Error') || log.contains('ERR:');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        log,
                        style: TextStyle(
                          color: isError
                              ? Colors.redAccent
                              : Colors.lightGreenAccent.withValues(alpha: 0.8),
                          fontFamily: 'Consolas',
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isDeploying)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: theme.colorScheme.primary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Executing deployment commands...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeploying ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Close',
            style: TextStyle(
              color: _isDeploying ? Colors.grey : theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
