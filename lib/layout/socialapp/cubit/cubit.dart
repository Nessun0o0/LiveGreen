import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:socialapp/layout/socialapp/cubit/state.dart';

import '../../../models/social_model/LikeModel.dart';
import '../../../models/social_model/comment_model.dart';
import '../../../models/social_model/message_model.dart';
import '../../../models/social_model/post_model.dart';
import '../../../models/social_model/social_user_model.dart';
import '../../../modules/chats/chats.dart';
import '../../../modules/feeds/feeds.dart';
import '../../../modules/new_post/new_post.dart';

import '../../../modules/settings/Profile_screen.dart';
import '../../../modules/social_login/social_login_screen.dart';
import '../../../modules/users/users.dart';
import '../../../shared/components/components.dart';
import '../../../shared/components/constants.dart';
import '../../../shared/network/local/cache_helper.dart';


class SocialCubit extends Cubit<SocialStates> {
  SocialCubit() : super(SocialInitialState());


  static SocialCubit get(context) => BlocProvider.of(context);
  SocialUserModel? socialUserModel;
  int currentIndex = 0;
  List<Widget> screens = [
    Feeds(),
    Chats(),
    NewPostScreen(),
    Users(),
    ProfileScreen(),
  ];
  List<String> titles = ['Home', 'Chats', 'Post', 'Users', 'Settings'];
  void changeBottomNav(int index) {
    if (index == 1) {
      getAllUsers();
    }
    if (index == 4) {
      getUserData(uId);
    }
    if (index == 2) {
      emit(SocialNewPostState());
    } else {
      currentIndex = index;
      emit(SocialChangeBottomNav());
    }
  }

  //USER DATA

  File? profileImage;
  File? coverImage;
  List<SocialUserModel> users = [];
  var picker = ImagePicker();
  void getUserData(String? uId) {
    emit(SocialGetUserLoadingState());
    uId = CacheHelper.getData(key: 'uId');
    FirebaseFirestore.instance.collection('users').doc(uId).get().then((value) {
      socialUserModel = SocialUserModel.fromJson(value.data());
      if (kDebugMode) {
        print(socialUserModel.toString());
      }

      emit(SocialGetUserSuccessState());
    }).catchError((error) {
      print(error.toString());
      emit(SocialGetUserErrorState(error.toString()));
    });
  }
  void getAllUsers() {
    emit(SocialGetAllUserLoadingState());
    users = [];
    {
      FirebaseFirestore.instance.collection('users').get().then((value) {
        for (var element in value.docs) {
          if (element.data()['uId'] != socialUserModel!.uId)
          {
            users.add(SocialUserModel.fromJson(element.data()));
            print(users.toString());
          }
        }
        emit(SocialGetAllUserSuccessState());
        print(users.toString());
      }).catchError((error) {
        emit(SocialGetAllUserErrorState(error.toString()));
      });
    }
  }
  Future<void> getCoverImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      coverImage = File(pickedFile.path);
      emit(SocialCoverSuccessState());
    } else {
      print('No image selected');
      emit(SocialCoverErrorState());
    }
  }
  Future<void> getProfileImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      profileImage = File(pickedFile.path);
      emit(SocialProfileImageSuccessState());
    } else {
      print('No image selected');
      emit(SocialProfileImageErrorState());
    }
  }
  void uploadProfileImage({
    required String name,
    required String phone,
    required String bio,
  }) {
    emit(SocialUploadProfileImageLoadingState());
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child('users/${Uri
        .file(profileImage!.path)
        .pathSegments
        .last}')
        .putFile(profileImage!)
        .then((value) {
      value.ref.getDownloadURL().then((value) {
        emit(SocialUploadProfileImageSuccessState());
        print(value);
        updateUser(name: name, phone: phone, bio: bio, image: value);

      }).catchError((error) {
        emit(SocialUploadProfileImageErrorState());
      });
    }).catchError((error) {
      emit(SocialUploadProfileImageErrorState());
    });
  }
  void uploadCoverImage({
    required String name,
    required String phone,
    required String bio,
  }) {
    emit(SocialUploadCoverImageLoadingState());
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child('users/${Uri
        .file(coverImage!.path)
        .pathSegments
        .last}')
        .putFile(coverImage!)
        .then((value) {
      value.ref.getDownloadURL().then((value) {
        //emit(SocialUploadCoverSuccessState());
        print(value);
        updateUser(name: name, phone: phone, bio: bio, cover: value);
      }).catchError((error) {
        emit(SocialUploadCoverErrorState());
      });
    }).catchError((error) {
      emit(SocialUploadCoverErrorState());
    });
  }
  void updateUser({
    required String name,
    required String phone,
    required String bio,
    String? cover,
    String? image,
  }) {
    emit(SocialUserUpdateLoadingState());
    SocialUserModel model = SocialUserModel(
      name: name,
      phone: phone,
      bio: bio,
      email: socialUserModel!.email,
      uId: socialUserModel!.uId,
      cover: cover ?? socialUserModel!.cover,
      image: image ?? socialUserModel!.image,

    );
    FirebaseFirestore.instance
        .collection('users')
        .doc(socialUserModel!.uId)
        .update(model.toMap())
        .then((value) {
      getUserData(uId);
    }).catchError((error) {
      emit(SocialUserUpdateErrorState());
    });
  }



//POST DATA
  List<PostModel> posts = [];
  PostModel? postModel;
  PostModel? singlePost;
  void uploadPost({
    String? name, String? image, String? postText,
    String? date, String? time,
  }) {
    emit(SocialCreatePostLoadingState());
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child(Uri.file(postImage!.path)
        .pathSegments
        .last)
        .putFile(postImage!)
        .then((value) {
      value.ref.getDownloadURL().then((value) {
        if (kDebugMode) {
          print(value);
        }
        createPost(
          name: name,
          image: image,
          postImage: value,
          postText: postText,
            time: time,
            date: date,
        );
        emit(SocialCreatePostSuccessState());
      }).catchError((error) {
        emit(SocialCreatePostErrorState());
      });
    }).catchError((error) {
      emit(SocialCreatePostErrorState());
    });
  }
  void createPost({
    String? name,
    String? image,
    String? postText,
    String? postImage,
    String? date,
    String? time,
    String? dateTime,

  }) {
    emit(SocialCreatePostLoadingState());
    PostModel model = PostModel(
      name:name,
      uId: socialUserModel!.uId,
      image:image,
      text: postText,
      postImage: postImage,
      likes: 0,
      comments: 0,
      date: date,
      time: time,
      dateTime: FieldValue.serverTimestamp());

    FirebaseFirestore.instance
        .collection('posts')
        .add(model.toMap())
        .then((value) {
      emit(SocialCreatePostSuccessState());
    }).catchError((error) {
      emit(SocialCreatePostErrorState());
    });
  }
  void deletePost(String? postId) {
    FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .delete()
        .then((value) {
      showToast(text: "Post Deleted", state: ToastStates.ERROR);
      emit(DeletePostSuccessState());
    });
  }
  void removePostImage() {
    postImage = null;
    emit(SocialRemovePostState());
  }
  void getPosts() {
    FirebaseFirestore.instance
        .collection('posts')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .listen((event) async {
      posts=[];
      event.docs.forEach((element) async {
        posts.add(PostModel.fromJson(element.data()));
        var likes = await element.reference.collection('likes').get();
        var comments = await element.reference.collection('comments').get();
        await FirebaseFirestore.instance.collection('posts').doc(element.id)
            .update(({
          'likes':likes.docs.length,
          'comments':comments.docs.length,
          'postId': element.id,
        }));
      });
      emit(SocialGetPostsSuccessState());

    });

  }
  Future<bool> likedByMe(
      {context,
        String? postId,
        PostModel? postModel,
        SocialUserModel? postUser}) async {
    emit(SocialLikePostsLoadingState());
    bool isLikedByMe = false;
    FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get()
        .then((event) async {
      var likes = await event.reference.collection('likes').get();
      likes.docs.forEach((element) {
        if (element.id == socialUserModel!.uId) {
          isLikedByMe = true;
          //disLikePost(postId);
        }
      });
      if (isLikedByMe == false) {
        likePost(
            postId: postId,
            context: context,
            postModel: postModel,
            postUser: postUser);
      }
      print(isLikedByMe);
      emit(SocialLikePostsSuccessState());
    });
    return isLikedByMe;
  }
  Future<void> getPostImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      postImage = File(pickedFile.path);
      emit(SocialPostSuccessState());
    } else {
      if (kDebugMode) {
        print('No image selected');
      }
      emit(SocialPostErrorState());
    }
  }

  void likePost({context, String? postId, PostModel? postModel, SocialUserModel? postUser,String?dateTime}) {
    LikesModel likesModel = LikesModel(
      uId: socialUserModel!.uId,
      name: socialUserModel!.name,
      image: socialUserModel!.image,
        dateTime: FieldValue.serverTimestamp());
    FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(socialUserModel!.uId)
        .set(likesModel.toMap())
        .then((value) {
      getPosts();

      emit(SocialLikePostsSuccessState());
    }).catchError((error) {
      emit(SocialLikePostsErrorState(error.toString()));
    });
  }




//comment data
  List<CommentModel> comments = [];
  CommentModel ? commentModel;
  File? postImage;

  void commentPost({
    required String? postId,
     String ? comment,
    Map<String, dynamic>? commentImage,
    required String? time,
    required String? date,
  }) {
    CommentModel commentModel = CommentModel(
      name: socialUserModel!.name,
      image: socialUserModel!.image,
      commentText: comment,
      commentImage: commentImage,
      time: time, date: date,
      dateTime: FieldValue.serverTimestamp());
    emit(SocialCommentLoadingState());
    FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(commentModel.toMap())
        .then((value) {
      getPosts();
      emit(SocialCommentSuccessState());
        }).catchError((error) {

      if (kDebugMode) {
        print(error.toString());
      }
      emit(SocialCommentErrorState(error.toString()));
    });
  }
  bool isCommentImageLoading = false;
  String? commentImageURL;
  File? commentImage;
  void uploadCommentPic({
    required String? postId,
    String? commentText,
    required String? time,
    required String? date,
  }) {
    isCommentImageLoading = true;
    emit(UploadCommentPicLoadingState());
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child(Uri.file(commentImage!.path).pathSegments.last)
        .putFile(commentImage!)
        .then((value) {
      value.ref.getDownloadURL().then((value) {
        commentImageURL = value;
        commentPost(
          postId: postId,
          comment: commentText,
          commentImage: {
            'width' : 150,
            'image' : value,
            'height': 200
          },
          time: time,
          date: date,);
        emit(UploadCommentPicSuccessState());
        isCommentImageLoading = false;
      }).catchError((error) {
        if (kDebugMode) {
          print('Error While getDownload CommentImageURL ' + error);
        }
        emit(UploadCommentPicErrorState());
      });
    }).catchError((error) {
      if (kDebugMode) {
        print('Error While putting the File ' + error);
      }
      emit(UploadCommentPicErrorState());
    });
  }
  void getComments(postId) {
    emit(GetCommentLoadingState());
    FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection("comments")
        .orderBy('dateTime')
        .snapshots()
    .listen((event) {
      comments.clear();
      event.docs.forEach((element) {
       comments.add(CommentModel.fromJson(element.data()));
       emit(GetCommentSuccessState());
      });
    });
  }
  Future getCommentImage() async {
    emit(UpdatePostLoadingState());
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    print('Selecting Image...');
    if (pickedFile != null) {
      commentImage = File(pickedFile.path);
      print('Image Selected');
      emit(GetCommentPicSuccessState());
    } else {
      print('No Image Selected');
      emit(GetCommentPicErrorState());
    }
  }
  void popCommentImage() {
    commentImage = null;
    emit(DeleteCommentPicState());
  }


//message data
  String? imageURL;
  bool isMessageImageLoading = false;
  List<MessageUserModel> message = [];
  File? messageImage;

  void sendMessage({
    required String? receiverId,
    String? text,
    Map<String, dynamic>? messageImage,
    required String? time,
    required String? date,
  }) {
    MessageUserModel messageModel = MessageUserModel(
      senderId: socialUserModel!.uId,
      receiverId: receiverId,
      messageImage:messageImage ,
      text: text,
        time: time,
        date: date,
        dateTime: FieldValue.serverTimestamp()
    );
    FirebaseFirestore.instance
        .collection('users')
        .doc(socialUserModel!.uId)
        .collection('chats')
        .doc(receiverId)
        .collection('message')
        .add(messageModel.toMap())
        .then((value) async {
      emit(SocialSendMessageSuccessState());
    }).catchError((error) {
      print(error.toString());
      emit(SocialSendMessageErrorState());
    });

    FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .collection('chats')
        .doc(socialUserModel!.uId)
        .collection('message')
        .add(messageModel.toMap())
        .then((value) {
      emit(SocialSendMessageSuccessState());
    }).catchError((error) {
      print(error.toString());
      emit(SocialSendMessageErrorState());
    });
  }

  void uploadMessagePic({
    String ? senderId,
    required String? receiverId,
    String? text,
    required String? time,
    required String? date,
  }) {
    isMessageImageLoading = true;
    emit(UploadMessagePicLoadingState());
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child(Uri.file(messageImage!.path)
        .pathSegments
        .last)
        .putFile(messageImage!)
        .then((value) {
      value.ref.getDownloadURL().then((value) {
        imageURL = value;
        sendMessage(
          receiverId: receiverId,
          text: text,
          messageImage: {
            'width': 150,
            'image': value,
            'height': 200
          },
          time: time,
          date: date,);
        emit(UploadMessagePicSuccessState());
        isMessageImageLoading = false;
      }).catchError((error) {
        print('Error While getDownloadURL ' + error);
        emit(UploadMessagePicErrorState());
      });
    }).catchError((error) {
      print('Error While putting the File ' + error);
      emit(UploadMessagePicErrorState());
    });
  }

  void getMessage( {required String receiverId})
  {
    FirebaseFirestore.instance.collection('users')
        .doc(socialUserModel!.uId)
        .collection('chats')
        .doc(receiverId)
        .collection('message')
        .orderBy('dateTime')
        .snapshots()
        .listen((event)
    {
     message = [];
      for (var element in event.docs) {
        message.add(MessageUserModel.fromJson(element.data()));
      }
      emit(SocialGetMessageSuccessState());


    });
  }
  Future getMessageImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      messageImage = File(pickedFile.path);
      emit(GetMessagePicSuccessState());
    } else {
      print('No Image Selected');
      emit(GetMessagePicErrorState());
    }
  }

  void popMessageImage() {
    messageImage = null;
    emit(DeleteMessagePicState());
  }








  dynamic signOut(context) async {
    await CacheHelper.removeData(
      key: 'uId',
    ).then((value) {
      if (value) {
        navigateAndFinish(context, SocialLoginScreen());
        SocialCubit.get(context).currentIndex = 0;
      }
    });
  }

  void setUserToken() async{
    String? token = await FirebaseMessaging.instance.getToken();
    await FirebaseFirestore.instance.collection('users').doc(socialUserModel!.uId)
        .update({'token': token})
        .then((value) => {});
  }

  Future getMyData() async {

    FirebaseFirestore.instance
        .collection('users')
        .doc(uId!)
        .snapshots()
        .listen((value) async {
      socialUserModel = SocialUserModel.fromJson(value.data());
      setUserToken();

    });
  }

}
