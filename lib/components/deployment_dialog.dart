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
    return AlertDialog(
      title: Text(
        '${widget.mode == 'initial' ? 'Initial' : 'Update'} Deployment: ${widget.client.name}',
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[index],
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_isDeploying)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeploying ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
