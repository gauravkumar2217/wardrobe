import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/banner.dart' as models;

/// Widget to display multiple banners as a slider/carousel
class BannerSliderWidget extends StatefulWidget {
  final List<models.Banner> banners;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool autoPlay;
  final Duration autoPlayInterval;

  const BannerSliderWidget({
    super.key,
    required this.banners,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  @override
  State<BannerSliderWidget> createState() => _BannerSliderWidgetState();
}

class _BannerSliderWidgetState extends State<BannerSliderWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.autoPlay && widget.banners.length > 1) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (timer) {
      if (_pageController.hasClients && widget.banners.length > 1) {
        if (_currentPage < widget.banners.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.banners.length == 1) {
      return _buildSingleBanner(widget.banners.first);
    }

    // Determine dimensions based on banner type
    double bannerWidth = widget.width ?? MediaQuery.of(context).size.width;
    double bannerHeight = widget.height ?? _getDefaultHeight(widget.banners.first.type);

    return Column(
      children: [
        SizedBox(
          width: bannerWidth,
          height: bannerHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              return _buildBannerItem(widget.banners[index], bannerWidth, bannerHeight);
            },
          ),
        ),
        // Page indicators
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSingleBanner(models.Banner banner) {
    double bannerWidth = widget.width ?? MediaQuery.of(context).size.width;
    double bannerHeight = widget.height ?? _getDefaultHeight(banner.type);
    return _buildBannerItem(banner, bannerWidth, bannerHeight);
  }

  Widget _buildBannerItem(models.Banner banner, double width, double height) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: banner.imageUrl,
          fit: widget.fit,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  double _getDefaultHeight(String type) {
    // Calculate height based on banner type and screen width
    // For 320x100 banners, maintain aspect ratio
    if (type == '320x100') {
      return 100;
    }
    // For full screen banners, use screen height
    if (type == '1080x1920') {
      return 1920; // Will be constrained by parent
    }
    return 100; // Default height
  }
}
