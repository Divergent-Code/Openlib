import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BookGridItem extends StatelessWidget {
  final String title;
  final String thumbnail;
  final VoidCallback onTap;
  final double imageHeight;
  final double imageWidth;

  const BookGridItem({
    super.key,
    required this.title,
    required this.thumbnail,
    required this.onTap,
    this.imageHeight = 145,
    this.imageWidth = 105,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CachedNetworkImage(
              height: imageHeight,
              width: imageWidth,
              imageUrl: thumbnail,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withAlpha(100),
                        spreadRadius: 0.1,
                        blurRadius: 1)
                  ],
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              placeholder: (context, url) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                height: imageHeight,
                width: imageWidth,
              ),
              errorWidget: (context, url, error) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                  height: imageHeight,
                  width: imageWidth,
                  child: const Center(
                    child: Icon(Icons.image_rounded),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: imageWidth,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.displayMedium,
                  maxLines: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
