// Firebase Storage를 이용한 이미지 업로드 관리

const storageManager = {
    // 이미지 압축 함수 (클라이언트 측) - 해상도 낮추기로 비용 절감
    // 디바이스 픽셀 비율을 고려하여 모바일에서는 더 높은 해상도 사용
    async compressImage(file, maxWidth = null, maxHeight = null, quality = 0.80, useWebP = true) {
        // 디바이스 픽셀 비율 감지 (모바일 Retina 디스플레이 등)
        const devicePixelRatio = window.devicePixelRatio || 1;
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        const screenWidth = window.screen.width || 1920;
        
        // 기본 해상도 설정 (비용 절감을 위해 모바일도 낮춤)
        if (maxWidth === null || maxHeight === null) {
            if (isMobile) {
                // 모바일: 1080px로 제한 (비용 절감, 대부분의 모바일 화면에서 충분히 선명)
                // 고해상도 화면이어도 1080px면 충분히 선명하게 보임
                maxWidth = 1080;
                maxHeight = 1080;
            } else {
                // PC: 1080px (비용 절감)
                maxWidth = 1080;
                maxHeight = 1080;
            }
        }
        
        console.log(`📱 디바이스 정보: 모바일=${isMobile}, 픽셀비율=${devicePixelRatio}, 해상도=${maxWidth}x${maxHeight}px`);
        return new Promise((resolve, reject) => {
            // 이미지가 아닌 경우 원본 반환
            if (!file.type.startsWith('image/')) {
                resolve(file);
                return;
            }

            const reader = new FileReader();
            reader.onload = function(e) {
                const img = new Image();
                img.onload = function() {
                    // 원본 크기가 작고 파일 크기도 작으면 압축하지 않음
                    // 하지만 해상도가 크면 무조건 압축 (비용 절감을 위해)
                    if (img.width <= maxWidth && img.height <= maxHeight && file.size < 300000) {
                        console.log('ℹ️ 이미지가 이미 작아서 압축하지 않음:', file.size / 1024, 'KB');
                        resolve(file);
                        return;
                    }

                    // 캔버스 생성
                    const canvas = document.createElement('canvas');
                    let width = img.width;
                    let height = img.height;
                    const originalWidth = width;
                    const originalHeight = height;

                    // 비율 유지하며 크기 조정 (무조건 최대 해상도로 제한)
                    if (width > maxWidth || height > maxHeight) {
                        if (width > height) {
                            if (width > maxWidth) {
                                height = Math.round((height * maxWidth) / width);
                                width = maxWidth;
                            }
                        } else {
                            if (height > maxHeight) {
                                width = Math.round((width * maxHeight) / height);
                                height = maxHeight;
                            }
                        }
                    }
                    
                    // 해상도가 줄어들지 않았어도 파일 크기가 크면 압축
                    const needsCompression = (originalWidth > maxWidth || originalHeight > maxHeight) || file.size > 500000;
                    
                    if (!needsCompression && file.size < 500000) {
                        console.log('ℹ️ 압축 불필요:', file.size / 1024, 'KB');
                        resolve(file);
                        return;
                    }

                    canvas.width = width;
                    canvas.height = height;

                    // 이미지 그리기
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, width, height);

                    // WebP 포맷 사용 시도 (더 나은 압축률)
                    // 브라우저가 WebP를 지원하는지 확인
                    let supportsWebP = false;
                    if (useWebP && canvas.toBlob) {
                        try {
                            const testDataUrl = canvas.toDataURL('image/webp');
                            supportsWebP = testDataUrl.indexOf('data:image/webp') === 0;
                        } catch (e) {
                            supportsWebP = false;
                        }
                    }
                    
                    // WebP를 지원하면 WebP 사용, 아니면 JPEG 사용 (PNG보다 압축률이 좋음)
                    let outputType = 'image/jpeg';
                    let outputQuality = quality;
                    
                    if (supportsWebP) {
                        outputType = 'image/webp';
                        console.log('✅ WebP 포맷 사용 가능');
                    } else {
                        // JPEG 사용 (PNG보다 압축률이 좋음)
                        outputType = 'image/jpeg';
                        console.log('ℹ️ WebP 미지원, JPEG 사용');
                    }

                    // Blob으로 변환
                    canvas.toBlob(function(blob) {
                        if (blob) {
                            // 해상도가 줄어들었거나 파일 크기가 작아졌으면 압축된 파일 사용
                            const sizeReduced = blob.size < file.size;
                            const resolutionReduced = (width < originalWidth) || (height < originalHeight);
                            
                            // 해상도가 줄어들었으면 무조건 압축된 파일 사용 (비용 절감)
                            if (resolutionReduced || sizeReduced) {
                                const fileName = supportsWebP ? 
                                    file.name.replace(/\.[^/.]+$/, '.webp') : 
                                    file.name.replace(/\.[^/.]+$/, '.jpg');
                                const compressedFile = new File([blob], fileName, {
                                    type: outputType,
                                    lastModified: Date.now()
                                });
                                const sizeReduction = ((file.size - blob.size) / file.size * 100).toFixed(1);
                                console.log(`✅ 이미지 압축 성공: ${(file.size / 1024 / 1024).toFixed(2)}MB → ${(blob.size / 1024 / 1024).toFixed(2)}MB (${sizeReduction}% 감소)`);
                                console.log(`   해상도: ${originalWidth}x${originalHeight}px → ${width}x${height}px`);
                                console.log(`   포맷: ${file.type} → ${outputType}`);
                                resolve(compressedFile);
                            } else {
                                console.warn(`⚠️ 압축 효과 없음: 원본 ${(file.size / 1024 / 1024).toFixed(2)}MB, 압축 ${(blob.size / 1024 / 1024).toFixed(2)}MB`);
                                // 해상도가 줄어들었으면 무조건 사용
                                if (resolutionReduced) {
                                    const fileName = supportsWebP ? 
                                        file.name.replace(/\.[^/.]+$/, '.webp') : 
                                        file.name.replace(/\.[^/.]+$/, '.jpg');
                                    const compressedFile = new File([blob], fileName, {
                                        type: outputType,
                                        lastModified: Date.now()
                                    });
                                    console.log(`✅ 해상도 감소로 압축된 파일 사용`);
                                    resolve(compressedFile);
                                } else {
                                    resolve(file);
                                }
                            }
                        } else {
                            console.error('❌ Blob 변환 실패, 원본 사용');
                            resolve(file);
                        }
                    }, outputType, outputQuality);
                };
                img.onerror = function() {
                    resolve(file); // 오류 시 원본 반환
                };
                img.src = e.target.result;
            };
            reader.onerror = function() {
                resolve(file); // 오류 시 원본 반환
            };
            reader.readAsDataURL(file);
        });
    },

    // 이미지 업로드 함수 - 압축된 이미지와 원본 이미지를 모두 업로드
    // compress: true면 압축된 이미지만, false면 원본만, 'both'면 둘 다 업로드
    async uploadImage(file, path, compress = true, saveOriginal = false) {
        try {
            // Firebase Storage 초기화 확인
            if (!storage) {
                await this.waitForStorage();
            }

            // 인증 확인
            if (!firebaseAuth) {
                await this.waitForFirebaseAuth();
            }

            const currentUser = firebaseAuth.currentUser;
            if (!currentUser) {
                throw new Error('로그인이 필요합니다. 이미지 업로드를 위해 로그인해주세요.');
            }

            if (!file) {
                throw new Error('파일이 선택되지 않았습니다.');
            }

            const storageRef = storage.ref();
            const timestamp = Date.now();

            // 압축된 이미지 업로드 (기본적으로 사용)
            let compressedFile = file;
            let compressedUrl = null;
            
            if (compress !== false) {
                // 모바일도 1080px로 통일하고 품질을 0.75로 낮춰서 파일 크기 추가 절감
                compressedFile = await this.compressImage(file, null, null, 0.75, true);
                const compressedFileName = `${timestamp}_compressed_${compressedFile.name}`;
                const compressedImageRef = storageRef.child(`${path}/${compressedFileName}`);
                
                const compressedMetadata = {
                    contentType: compressedFile.type || 'image/webp',
                    customMetadata: {
                        uploadedBy: currentUser.uid,
                        uploadedAt: new Date().toISOString(),
                        isCompressed: 'true'
                    }
                };
                
                console.log('✅ 압축된 이미지 업로드 중...', compressedImageRef.fullPath);
                const compressedSnapshot = await compressedImageRef.put(compressedFile, compressedMetadata);
                compressedUrl = await compressedSnapshot.ref.getDownloadURL();
                console.log('✅ 압축된 이미지 업로드 완료');
            }

            // 원본 이미지 업로드 (saveOriginal이 true일 때만)
            let originalUrl = null;
            if (saveOriginal && file.size > 500000) { // 500KB 이상일 때만 원본 저장
                const originalFileName = `${timestamp}_original_${file.name}`;
                const originalImageRef = storageRef.child(`${path}/${originalFileName}`);
                
                const originalMetadata = {
                    contentType: file.type || 'image/jpeg',
                    customMetadata: {
                        uploadedBy: currentUser.uid,
                        uploadedAt: new Date().toISOString(),
                        isOriginal: 'true'
                    }
                };
                
                console.log('✅ 원본 이미지 업로드 중...', originalImageRef.fullPath);
                const originalSnapshot = await originalImageRef.put(file, originalMetadata);
                originalUrl = await originalSnapshot.ref.getDownloadURL();
                console.log('✅ 원본 이미지 업로드 완료');
            }

            // 원본 URL이 있으면 객체로 반환, 없으면 압축된 URL만 반환
            if (originalUrl) {
                return {
                    compressed: compressedUrl,
                    original: originalUrl
                };
            } else {
                return compressedUrl;
            }
        } catch (error) {
            console.error('❌ 이미지 업로드 오류:', error);
            
            // 에러 메시지 개선
            let errorMessage = '이미지 업로드에 실패했습니다.';
            
            if (error.code === 'storage/unauthorized') {
                errorMessage = '업로드 권한이 없습니다. Firebase Storage 보안 규칙을 확인해주세요.';
            } else if (error.code === 'storage/canceled') {
                errorMessage = '업로드가 취소되었습니다.';
            } else if (error.code === 'storage/unknown') {
                errorMessage = '알 수 없는 오류가 발생했습니다.';
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            throw new Error(errorMessage);
        }
    },

    // 이미지 삭제 함수
    async deleteImage(imageUrl) {
        try {
            if (!storage) {
                await this.waitForStorage();
            }

            // URL에서 이미지 경로 추출
            const imageRef = storage.refFromURL(imageUrl);
            await imageRef.delete();
            console.log('✅ 이미지 삭제 완료');
        } catch (error) {
            console.error('❌ 이미지 삭제 오류:', error);
            // 삭제 실패해도 계속 진행 (이미지가 없을 수 있음)
        }
    },

    // Firebase Storage 초기화 대기
    waitForStorage() {
        return new Promise((resolve, reject) => {
            let attempts = 0;
            const maxAttempts = 50; // 5초 대기

            const checkInterval = setInterval(() => {
                attempts++;
                
                if (storage) {
                    clearInterval(checkInterval);
                    resolve();
                } else if (attempts >= maxAttempts) {
                    clearInterval(checkInterval);
                    reject(new Error('Firebase Storage 초기화에 실패했습니다.'));
                }
            }, 100);
        });
    },

    // Firebase Auth 초기화 대기
    waitForFirebaseAuth() {
        return new Promise((resolve, reject) => {
            let attempts = 0;
            const maxAttempts = 50; // 5초 대기

            const checkInterval = setInterval(() => {
                attempts++;
                
                if (firebaseAuth) {
                    clearInterval(checkInterval);
                    resolve();
                } else if (attempts >= maxAttempts) {
                    clearInterval(checkInterval);
                    reject(new Error('Firebase Auth 초기화에 실패했습니다.'));
                }
            }, 100);
        });
    }
};

// 전역 접근을 위해 window 객체에 추가
window.storageManager = storageManager;
